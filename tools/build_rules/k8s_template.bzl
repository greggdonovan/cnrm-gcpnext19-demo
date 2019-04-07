load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_k8s//k8s:object.bzl", "k8s_object")
load("@io_bazel_rules_k8s//k8s:objects.bzl", "k8s_objects")
load("//tools/build_rules:k8s_contexts.bzl", "k8s_name_for_context")

# Introducing arbitrary dynamic args hurts caching and makes the build header to reason about, so
# we explicitly list them here to make it a purposeful change.
PERMITTED_DYNAMIC_ARGS = ["joblabel"]

def _k8s_template_impl(ctx):
    inputs = [ctx.executable.binary]

    arguments = []

    arguments += ["--binary-target-path", ctx.executable.binary.path]

    needs_stamp_file = False
    for arg in ctx.attr.dynamic_args:
        if arg not in PERMITTED_DYNAMIC_ARGS:
            fail("dynamic_arg '%s' is not permitted" % arg)
        if arg not in ctx.attr.constant_args:
            arguments += ["--dynamic_args", arg]
            needs_stamp_file = True

    if needs_stamp_file:
        # ctx.info_file is an undocumented Skylark hook for the workspace status vars
        # See: https://stackoverflow.com/questions/49879399/bazel-how-to-access-workspace-status-variables-in-skylark
        # Also see: https://www.kchodorow.com/blog/2017/03/27/stamping-your-builds/
        inputs.append(ctx.info_file)
        arguments += ["--stamp-info-file", ctx.info_file.path]

    if ctx.attr.constant_args:
        arguments += ["--constant_args", ";".join(["%s=%s" % (k, v) for (k, v) in ctx.attr.constant_args.items()])]

    arguments += ["--output", ctx.outputs.template.path]

    # For label_args, add each depset of files to the templater inputs and pass a constant_args argument with its name and path(s).
    # output:
    #   --constant_args 'my_tpl_files=file1.tpl,file2.tpl' --label_args 'my_input=one_file.tpl'
    for label, arg_name in ctx.attr.label_args.items() or {}:
        label_files_list = label.files.to_list()
        inputs += label_files_list
        arguments += ["--constant_args", "%s=%s" % (arg_name, ",".join([f.path for f in label_files_list]))]

    ctx.actions.run(
        inputs = inputs,
        mnemonic = "K8sTemplate",
        progress_message = "Test",
        outputs = [ctx.outputs.template],
        arguments = arguments,
        executable = ctx.executable._k8s_templater,
    )

    # By default (if you run `bazel build` on this target, or if you use it as a
    # source of another target), only the sha256 is computed.
    return DefaultInfo(files = depset([ctx.outputs.template]))

k8s_template = rule(
    attrs = {
        "binary": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            doc = """
binary is the label target that is called once all arguments are resolved.
""",
        ),
        "dynamic_args": attr.string_list(
            allow_empty = True,
            doc = """
dynamic_args are resolved from workspace status variables read from bazel-out/stable-status.txt.
stable status variables are lowercased and the STABLE_ prefix is removed before being mapped to program arguments.
e.g. STABLE_IMAGE_CHROOT is available to k8s_template binary targets as image_chroot. Adding a '?' to the end of your
argument will make it an optional argument.
""",
        ),
        "constant_args": attr.string_dict(
            allow_empty = True,
            doc = """
Fixed arguments to the binary that do not change based on namespace, cluster, or other variables. 
""",
        ),
        "label_args": attr.label_keyed_string_dict(
            allow_empty = True,
            doc = """
Labels of files that are to be added as inputs to the binary target. The Label key is added as an input and the string value is added as an argument that points to the resolved location of the file referenced by the label. If the label contains more than one file, their locations are passed comma-separated to the binary.'
""",
            allow_files = True,
        ),
        "_k8s_templater": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            default = "//tools/build_rules:k8s_templater",
        ),
    },
    outputs = {"template": "%{name}.yaml"},
    implementation = _k8s_template_impl,
)

def k8s_object_for_context(name, binary, k8s_context, constant_args = None, label_args = None, context_args = None, dynamic_args = None, apply_namespace = None, images = None, resolver_args = None, visibility = None):
    """Generates a k8s_template (from the binary + args) and k8s_object (from that template + images, with the optional overridden namespace).

    Args:
        name: unique name as returned by k8s_app_name, required
        binary: called to generate YAML, required
        k8s_context: a `context` provider, required
        constant_args: dict of key-value pairs that are passed to the binary, optional
        label_args: dict of key-label pairs; the path to the label's output is passed as that argument of the binary, optional
        context_args: list of keys to extract from the k8s_context and pass to the binary, optional
        dynamic_args: list of keys to extract from workspace vars and pass to the binary, optional
        apply_namespace: namespace to create the objects in, to override it to be other than the context's namespace, optional
        images: dict of images to resolve in the YAML, optional
        resolver_args: list of args to the rules_k8s resolver, optional
    """
    tpl_name = "%s_tpl" % name

    constant_args = constant_args or {}
    label_args = label_args or {}
    context_args = context_args or []
    dynamic_args = dynamic_args or []

    # Unpack the necessary arguments for the template from the context: the arguments required by
    # all templates, plus any that are explictly requested for this object.  They can be direct
    # attributes of the context, or could be taken from the constant_args set when declaring the
    # namespace.
    for arg in context_args + ["cluster", "namespace", "kubernetes_version"]:
        val = getattr(k8s_context, arg, None) or k8s_context.constant_args.get(arg)
        if not val:
            available_keys = k8s_context.constant_args.keys() + [k for k in dir(k8s_context) if getattr(k8s_context, k, None)]
            fail("unable to find '%s' in the context (available: %s)" % (arg, available_keys))
        constant_args[arg] = val

    k8s_template(
        name = tpl_name,
        binary = binary,
        constant_args = constant_args,
        dynamic_args = dynamic_args,
        label_args = label_args,
    )
    k8s_object(
        name = name,
        template = tpl_name,
        images = images or {},
        visibility = visibility,
        image_chroot = k8s_context.image_chroot,
        namespace = apply_namespace or k8s_context.namespace,
        cluster = k8s_context.cluster,
        user = k8s_context.user,
        resolver_args = resolver_args,
    )

def k8s_objects_for_contexts(name, k8s_contexts, **kwargs):
    for k8s_context in k8s_contexts:
        k8s_object_for_context(
            name = k8s_name_for_context(name, k8s_context),
            k8s_context = k8s_context,
            **kwargs
        )

def k8s_apps_for_contexts(name, k8s_contexts, objects, visibility = None):
    for k8s_context in k8s_contexts:
        k8s_objects(
            name = k8s_name_for_context(name, k8s_context),
            objects = [k8s_name_for_context(n, k8s_context) for n in objects],
            visibility = visibility,
        )

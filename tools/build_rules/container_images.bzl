load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@io_bazel_rules_docker//docker:docker.bzl", "docker_bundle")
load("@io_bazel_rules_docker//contrib:push-all.bzl", "docker_push")
load("@io_bazel_rules_docker//container:layer_tools.bzl", "get_from_target")

_images = provider(fields = {"images": "dict mapping image tag -> image Target"})
"""Provider used to store the results of the _k8s_images_aspect."""

def _images_from_targets(images, targets):
    """Given a dict and a set of targets, returns the sum of that dict and the images from the
    _images provider of any target that has it.

    Args:
    - images: dict mapping image tag -> image Target
    - targets: an object or list of objects, containing Targets to be useful
    """

    # Missing/empty attributes -- exit now.
    if not targets:
        return images

    # Some attributes are single-valued, some are lists; make them consistent.
    if type(targets) != "list":
        targets = [targets]
    for target in targets:
        # `targets` may contain types other than Target like Label; only Target would have
        # providers (see https://docs.bazel.build/versions/master/skylark/lib/Target.html).  If it
        # does, gather the transitive `images` from it.
        if type(target) == "Target" and _images in target and target[_images].images:
            images = dicts.add(images, target[_images].images)
    return images

def _full_image_tags(short_tag, image_chroot, namespace):
    '''For a short tag (e.g. "example:0xC0DEA5CF"), image_chroot (e.g.
    "us.gcr.io/cnrm-gcpnext19-demo"), and namespace (e.g. "cnrm-gcpnext19-demo"), returns a list of tags
    that should be pushed to that chroot for that image.'''
    image_name = short_tag.split(":")[0]
    latest_for_ns = "%s/%s:latest-%s" % (image_chroot, image_name, namespace)
    versioned = "%s/%s:{VERSION}" % (image_chroot, image_name)
    return [latest_for_ns, versioned]

def _k8s_images_aspect_impl(target, ctx):
    """This aspect accumulates Docker images from k8s_object targets.  See k8s_container_bundle for a full explanation."""

    # Inspect the current target's attributes.  If it is a k8s_object, it will have `images` and
    # `image_targets` attributes that we want.  `images` is a map of tag (like "mmx:0xC0DEA5CF") to
    # image label (as a string); `image_targets` is a list of the Targets for each of those string
    # values (in the same order).  The docker push command we are ultimately building needs a map
    # of tag to Targets, so generate the full tags and zip up a map.
    images = getattr(ctx.rule.attr, "images", {})
    image_targets = getattr(ctx.rule.attr, "image_targets", [])
    image_tags = {}
    if images and image_targets:
        for i, tag in enumerate(images.keys()):
            image_target = image_targets[i]
            for full_tag in _full_image_tags(tag, ctx.rule.attr.image_chroot, ctx.rule.attr.namespace):
                image_tags[full_tag] = image_target

        # Useful for debugging:
        #print('ASPECT IMAGES %s %s: %s' % (ctx.rule.kind, target.label, image_tags))

    # The aspect must also return the sum of the _images provider from any targets that are
    # referenced by the target currently being processed.  Bazel does not gather them itself,
    # leaving it up to the aspect here to walk the available attributes (which could be anything,
    # as `attr_aspects` was defined as `*`) and sum up the _images providers from them, with the
    # current target's images.
    for key in dir(ctx.rule.attr):
        targets = getattr(ctx.rule.attr, key, [])
        image_tags = _images_from_targets(image_tags, targets)
    return [_images(images = image_tags)]

_k8s_images_aspect = aspect(
    implementation = _k8s_images_aspect_impl,
    attr_aspects = ["*"],
)

def _k8s_container_bundle_impl(ctx):
    """k8s_container_bundle walks dependency tree and accumulate all docker images referenced in
    it.  Then, those images are tagged and bundled, so this target can be passed to rules_docker's
    docker_push, which will push those tags.

    The dependency tree is walked using the _k8s_images_aspect (because it is specified in
    attrs.deps.aspects when this rule is created).  Starting with each target passed to this rule's
    `deps`, the _k8s_image_aspect is run on that target.  Then, the image is run recursively on
    every dependency of that target; in that way, it processes the entire dependency tree.  At each
    target, the aspect checks if it is a rules_k8s k8s_object.  If so, the image map passed to that
    rule (which rules_k8s uses for resolving images to digests) is repurposed to generate a map of
    tags for that image.  If the target is any other type, the aspect is a no-op and continues down
    the tree.  When this rule is run, the aspects have been fully executed, and this rule gets
    access to the aspect's results via the _images provider, using them to build the bundle.
    """

    # The aspect will have been run on every target in `ctx.attr.deps`.  Gather those into a single
    # dictionary of tag -> Target.
    combined_image_tags = _images_from_targets({}, ctx.attr.deps)
    # Useful for debugging:
    #print('RULE IMAGES: %s' % combined_image_tags)

    # Now, return the data that rules_docker's //contrib/push-all.bzl:docker_push needs to push
    # those images with those tags.  This is the core of
    # //container/bundle.bzl:_container_bundle_impl from rules_docker -- processing each target
    # into layers, then returning a struct with the expected shape.  We don't need the rest of
    # container_bundle's return values (like the executable) because we don't use the bundle for
    # `docker load` or anything else, only as a source for docker_push.  We can't call
    # container_bundle directly because rules can't instantiate other rules.
    layer_tags = {
        tag: get_from_target(ctx, ctx.label.name, image)
        for tag, image in combined_image_tags.items()
    }
    return struct(
        container_images = layer_tags,
        stamp = True,
    )

k8s_container_bundle = rule(
    implementation = _k8s_container_bundle_impl,
    attrs = {
        "deps": attr.label_list(aspects = [_k8s_images_aspect]),
    },
)

def tagged_image_keys(images):
    """Given a map { image name -> container image label } return the same map with the 
       default bogus image tag appended to all keys. Useful for k8s_object, as k8s_object
       employs a naive sustitution policy of image names when replacing them with SHA256.

    Args:
      images: a dict of image name to container label

    Returns:
      A new dictionary with our default bogus_image_tag appended to all keys.
    """
    return {tagged_image(image_name): label for (image_name, label) in images.items()}

# Bogus sentinel value
bogus_image_tag = "0xC0DEA5CF"

def tagged_image(image_name):
    """Applies our bogus_image_tag to the unqualified image_name.

    Args:
      image_name: An unqualified docker image name.

    Returns:
      An image name with the bogus docker tag applied. This allows rules_k8s to substitute the docker tag without accidentally
      substituting anything else in the YAML.
    """
    return "%s:%s" % (image_name, bogus_image_tag)

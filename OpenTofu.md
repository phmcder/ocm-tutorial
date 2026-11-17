
The instructions to package a module can be found [here](https://opentofu.org/docs/cli/oci_registries/module-package/). There is no opentofu cli command to upload a module to an OCI container but the tutorial gives instructions on how to use ORAS cli instead. Notice that we set the manifest to have `mediaType="application/vnd.opentofu.modulepkg"` and the layer to have `mediaType="archive/zip"`
```bash
zip -r ./_output/opentofu-module.zip ./opentofu-module
oras push --artifact-type=application/vnd.opentofu.modulepkg \
  localhost:5000/opentofu-module:1.0.0 \
  ./_output/opentofu-module.zip:archive/zip
```

To see what we have done we can use ORAS to return the manifest
```bash
oras manifest fetch localhost:5000/opentofu-module:1.0.0 --format json
```
output
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/vnd.opentofu.modulepkg",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2,
    "data": "e30="
  },
  "layers": [
    {
      "mediaType": "archive/zip",
      "digest": "sha256:03d3b5e82095746040ea2f78e7e406a33387a60a7f07fc5dc11805490136487a",
      "size": 1221,
      "annotations": {
        "org.opencontainers.image.title": "_output/opentofu-module.zip"
      }
    }
  ],
  "annotations": { "org.opencontainers.image.created": "2026-11-16T20:06:19Z" }
}
```

```bash
oras blob fetch localhost:5000/opentofu-module:@sha256:03d3b5e82095746040ea2f78e7e406a33387a60a7f07fc5dc11805490136487a --output _output/opentofu-module.zip
unzip _output/opentofu-module.zip -d ./_output
```
The contents of the `oci-chart.tar.gz` is the helm chart directory called `hello-world` containing the chart.yaml, values.yaml and template.
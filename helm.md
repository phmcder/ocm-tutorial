```bash
helm package ./helm --destination ./_output
helm push ./_output/hello-world-1.0.0.tgz oci://localhost:5000/charts/hello-world --plain-http
```

```bash
oras manifest fetch localhost:5000/charts/hello-world/hello-world:1.0.0 --format json
```
```json
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.cncf.helm.config.v1+json",
    "digest": "sha256:29ceb39d2de5f21ed34132328e61dbfe42f0ee18c64c9662d8d6d2446c27b661",
    "size": 157
  },
  "layers": [
    {
      "mediaType": "application/vnd.cncf.helm.chart.content.v1.tar+gzip",
      "digest": "sha256:5e17506d098c893015e65720881c8e15eaa2af85536840b74b6464da73f4a164",
      "size": 371
    }
  ],
  "annotations": {
    "org.opencontainers.image.created": "2026-11-16T19:29:45Z",
    "org.opencontainers.image.description": "A Helm chart to deploy a hello-world pod",
    "org.opencontainers.image.title": "hello-world",
    "org.opencontainers.image.version": "1.0.0"
  }
}
```

```bash
oras manifest fetch-config localhost:5000/charts/hello-world/hello-world:1.0.0 --pretty
```
```json
{
  "name": "hello-world",
  "version": "1.0.0",
  "description": "A Helm chart to deploy a hello-world pod",
  "apiVersion": "v2",
  "appVersion": "1.0.0",
  "type": "application"
}
```

helm show all oci://localhost:5000/charts/hello-world/hello-world --version 1.0.0

helm template myrelease oci://localhost:5000/charts/hello-world/hello-world --version 1.0.0

```bash
oras blob fetch localhost:5000/charts/hello-world/hello-world@sha256:5e17506d098c893015e65720881c8e15eaa2af85536840b74b6464da73f4a164 --output _output/oci-chart.tar.gz
tar -xzf "./_output/oci-chart.tar.gz" -C "./_output"
```
The contents of the `oci-chart.tar.gz` is the helm chart directory called `hello-world` containing the chart.yaml, values.yaml and template.
# OCI Registry as a Container Store (ORAS)

## Upload and download random objects to an OCI Registry
```bash
echo "Hello World" > _output/some-text.txt
oras push localhost:5000/some-text:v1 _output/some-text.txt
```

We can then pull the manifest that was created for this artifact
```bash
oras manifest fetch --pretty localhost:5000/some-text:v1
```
Eaxmple Output:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/vnd.unknown.artifact.v1",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2,
    "data": "e30="
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar",
      "digest": "sha256:d2a84f4b8b650937ec8f73cd8be2c74add5a911ba64df27458ed8229da804a26",
      "size": 12,
      "annotations": {
        "org.opencontainers.image.title": "_output/some-text.txt"
      }
    }
  ],
  "annotations": {
    "org.opencontainers.image.created": "2026-11-20T10:49:59Z"
  }
}
```
You notice the manifest has an `artifactType` of `application/vnd.unknown.artifact.v1` and a layer with `mediaType` of `application/vnd.oci.image.layer.v1.tar`. To make this more useful we should change these values to allow tools and users to understand the content. 
```bash
oras push --artifact-type application/our-artifact+type localhost:5000/some-text:v1 _output/some-text.txt:text/plain
oras manifest fetch --pretty localhost:5000/some-text:v1
```
Example Output:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/our-artifact+type",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2,
    "data": "e30="
  },
  "layers": [
    {
      "mediaType": "text/plain",
      "digest": "sha256:d2a84f4b8b650937ec8f73cd8be2c74add5a911ba64df27458ed8229da804a26",
      "size": 12,
      "annotations": {
        "org.opencontainers.image.title": "_output/some-text.txt"
      }
    }
  ],
  "annotations": {
    "org.opencontainers.image.created": "2026-11-20T10:58:08Z"
  }
}
```
Now we have a more informative manifest file to understand what it contains. However, we don't want to have to create a manifest per file. We want to be able to store multiple files. We just add more files to our push command.
```bash
echo "More data" > _output/more-text.txt
mkdir _output/somedata
echo "Test 1" > _output/somedata/test1.txt
echo "Test 2" > _output/somedata/test2.txt
tar -czf _output/somedata.tar.gz -C _output somedata
oras push --artifact-type application/our-artifact+type localhost:5000/some-text:v1 \
_output/some-text.txt:text/plain \
_output/more-text.txt:text/plain \
_output/somedata.tar.gz:application/somefiles.v1.tar+gzip
oras manifest fetch --pretty localhost:5000/some-text:v1
```
Example Output:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/our-artifact+type",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2,
    "data": "e30="
  },
  "layers": [
    {
      "mediaType": "text/plain",
      "digest": "sha256:d2a84f4b8b650937ec8f73cd8be2c74add5a911ba64df27458ed8229da804a26",
      "size": 12,
      "annotations": {
        "org.opencontainers.image.title": "_output/some-text.txt"
      }
    },
    {
      "mediaType": "text/plain",
      "digest": "sha256:f6396355e9f8d875ed5c728bee497a7e505999ac00fc49092345711c6c65cceb",
      "size": 10,
      "annotations": {
        "org.opencontainers.image.title": "_output/more-text.txt"
      }
    },
    {
      "mediaType": "application/somefiles.v1.tar+gzip",
      "digest": "sha256:8de46140fa86c5051696ff8b7ece8fd090b6a0c8b96b73286efe1ba13b931ca3",
      "size": 192,
      "annotations": {
        "org.opencontainers.image.title": "_output/somedata.tar.gz"
      }
    }
  ],
  "annotations": {
    "org.opencontainers.image.created": "2026-11-20T11:09:37Z"
  }
}
```
We can use ORAS to download any of the layers in our artifact. Just make a note of the digest value for the required layer and run the following command
```bash
export LayerSha="sha256:f6396355e9f8d875ed5c728bee497a7e505999ac00fc49092345711c6c65cceb"
oras blob fetch --output _output/download.txt --pretty localhost:5000/some-text@$LayerSha
cat _output/download.txt
```




## Build a container the hard way
Now we know how to upload files to an OCI registry, lets try something more complicated. The following takes you through how to replicate the workflow that the docker CLI follows to add a container to the registry.

Docker is able to write the output of a docker build to and OCI tar file. The internals of the tar use the [OCI Layout](https://specs.opencontainers.org/image-spec/image-layout/). The following command build the `./dockerfile` and outputs it to `_output/oras-hello-world.tar`
```bash
docker build . -f dockerfile --output type=oci,dest=_output/oras-hello-world.tar -t oras-hello-world:v1
```
The above file contains a number of files and directories which we could individually add to a `oras push` command but if a source already in OCI format then we can use `oras cp` to upload the layout.

```bash
oras cp --from-oci-layout _output/oras-hello-world.tar:v1 localhost:5000/oras-hello-world:v1
```
Again you can view the the uploaded image in Zot at http://localhost:5000/image/oras-hello-world and can download the manifest using the follwing ORAS command
```bash
oras manifest fetch localhost:5000/oras-hello-world:v1
```
Output:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:a5a08aa603fb886d94892aeb26a33acc1568d24c0e2c291ce5b621680b020f67",
    "size": 821
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:fea5b91588ca539ff8a89d7d5df6c6d65d6ab7bd89145ba57f32c302cf02ffbe",
      "size": 4127385
    }
  ]
}
```

## View the config for a manifest
The returned manifest from above has a `config` that contains the Docker Runtime configuration require to run this application. ORAS has a useful function for downloading this
```bash
oras manifest fetch-config localhost:5000/oras-hello-world:v1
```

## Create a SBOM
Use Syft from Docker Hub to generate an SPDX JSON SBOM write it to `_output/oras-hello-world.spdx.json`. 
```bash
./scripts/generate-sbom.sh localhost:5000/oras-hello-world:v1 _output/oras-hello-world.spdx.json
```
We can then attach the SBOM to the container in the OCI Registry
```bash
oras attach --artifact-type application/spdx+json \
  --annotation "org.opencontainers.image.description=SPDX SBOM of oras-helloworld:v1" \
  localhost:5000/oras-hello-world:v1 _output/oras-hello-world.spdx.json:application/spdx+json
```

## Sign a container
Use `cleanstart/cosign` from Docker Hub. This is a third-party image, not an
official Sigstore image; only use it if you trust its publisher with your signing
key. The example below uses Cosign v3.1.3.

Generate an EC P-256 key pair using an OpenSSL container from Docker Hub:
```bash
./scripts/build-signing-keys.sh
```

Use the following generate the signature for the container. The function outputs the signing payload to `_output/cosign-bundle.json`.
```bash
./scripts/sign-container.sh localhost:5000/oras-hello-world:v1 cosign-bundle.json
```
```bash
oras attach --artifact-type application/vnd.dev.sigstore.bundle.v0.3+json \
  --annotation "dev.sigstore.bundle.content=dsse-envelope" \
  --annotation  "dev.sigstore.bundle.predicateType=https://sigstore.dev/cosign/sign/v1" \
  --annotation "org.opencontainers.image.created=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  localhost:5000/oras-hello-world:v1 _output/cosign-bundle.json:application/vnd.dev.sigstore.bundle.v0.3+json
```

## See attached files
The above actions have attached themselves to the container image in the zod registry. We can use ORAS to list all the artifacts that reference our image using the `discover` command

```bash
oras discover localhost:5000/oras-hello-world:v1
```
Example output:
```bash
localhost:5000/oras-hello-world@sha256:3758bbde04ad2177b5c22b3fa378daad71b77636c383ca4c16fdca2f12c7cb4b
├── application/spdx+json
│   └── sha256:0f70462e83f37be72a43b95db7a95feb53233ed351181453d2a66b86b001de48
│       └── [annotations]
│           ├── org.opencontainers.image.description: SPDX SBOM of oras-helloworld:v1
│           └── org.opencontainers.image.created: "2026-11-18T16:56:55Z"
└── application/vnd.dev.sigstore.bundle.v0.3+json
    └── sha256:e25acada5c0c801c345055ed48a4e6627a72c0a6eaf41b339776d784bfb29eb5
        └── [annotations]
            ├── dev.sigstore.bundle.content: dsse-envelope
            ├── dev.sigstore.bundle.predicateType: https://sigstore.dev/cosign/sign/v1
            └── org.opencontainers.image.created: "2026-11-20T09:24:29Z"
```

Each branch in the tree is a manifest. You can use oras to fetch the manifest. Simply pick one of the branches and copy the sha for the following command
```bash
#change the sha below before using
export BranchSha="sha256:e25acada5c0c801c345055ed48a4e6627a72c0a6eaf41b339776d784bfb29eb5"
oras manifest fetch --pretty localhost:5000/oras-hello-world@$BranchSha
```
Example Output for Signing:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "size": 2,
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "artifactType": "application/vnd.dev.sigstore.bundle.v0.3+json"
  },
  "layers": [
    {
      "mediaType": "application/vnd.dev.sigstore.bundle.v0.3+json",
      "size": 667,
      "digest": "sha256:bfd108b45c7dc6558e4dd7a2abe975cf761e86fa576fb057e17b28af387a8ba3"
    }
  ],
  "annotations": {
    "dev.sigstore.bundle.content": "dsse-envelope",
    "dev.sigstore.bundle.predicateType": "https://sigstore.dev/cosign/sign/v1",
    "org.opencontainers.image.created": "2026-11-20T09:24:29Z"
  },
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "size": 480,
    "digest": "sha256:3758bbde04ad2177b5c22b3fa378daad71b77636c383ca4c16fdca2f12c7cb4b"
  },
  "artifactType": "application/vnd.dev.sigstore.bundle.v0.3+json"
}
```
Example Output for SBOM:
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "artifactType": "application/spdx+json",
  "config": {
    "mediaType": "application/vnd.oci.empty.v1+json",
    "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
    "size": 2,
    "data": "e30="
  },
  "layers": [
    {
      "mediaType": "application/spdx+json",
      "digest": "sha256:76d12f5491846cddfb85c9f3759bdf4e203cd78e13b68729264093834f7e4316",
      "size": 95936,
      "annotations": {
        "org.opencontainers.image.title": "_output/oras-hello-world.spdx.json"
      }
    }
  ],
  "subject": {
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "digest": "sha256:3758bbde04ad2177b5c22b3fa378daad71b77636c383ca4c16fdca2f12c7cb4b",
    "size": 480
  },
  "annotations": {
    "org.opencontainers.image.created": "2026-11-18T16:56:55Z",
    "org.opencontainers.image.description": "SPDX SBOM of oras-helloworld:v1"
  }
}
```
Each of the above has a `subject` field pointing to the Container and `artifactType` telling us what the manifest describes. The `config` value for each has the `mediaType` set to `application/vnd.oci.empty.v1+json`, this complies with the OCI 1.1 specifiaction informing any application that there is no configuration set for these artifacts.

Each artifact has a single layer. This is the contents we uploaded using oras attach. We can use the ORAS CLI to download these objects. Similar to the above, you need to provide the `sha` for the layer you want to download. An example is below
```bash
export BlobSha="sha256:bfd108b45c7dc6558e4dd7a2abe975cf761e86fa576fb057e17b28af387a8ba3"
# View the OCI Content Descriptor
oras blob fetch --descriptor --pretty localhost:5000/oras-hello-world@$BlobSha
# Download the Blob
oras blob fetch --output _output/blob.json --pretty localhost:5000/oras-hello-world@$BlobSha
cat _output/blob.json
```

## Transferring to another registry
Now we have all the artifacts in our registry, how might we distribute them easily. ORAS has support for that in the CLI. First we can backup our container and all of the attached artifacts to a directory
```bash
oras backup --include-referrers --output _output/oras-hello-world-backup localhost:5000/oras-hello-world:v1
```
or we can backup to a tar file
```bash
oras backup --include-referrers --output _output/oras-hello-world-backup.tar localhost:5000/oras-hello-world:v1
```
We can then transfer this to an air-gapped registry and perform the `restore` using the following command
we can then restore to another OCI Register
```bash
export TARGET_OCI_REGISTRY="myregistry.example.com"
oras restore --input _output/oras-hello-world-backup.tar $TARGET_OCI_REGISTRY/oras-hello-world:v1
```


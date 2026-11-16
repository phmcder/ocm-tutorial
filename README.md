# Pre-Requisites
To follow this tutorial you need the 



# Docker and OCI
In this tutorial we will be looking at the structure of an OCI registry and how it stores information. OCI stands for the Open Container Initiative and it defines the specifications and standards for container building and deployment. Docker donated it's container runtime code as the starting point of the OCI in June 2015. The OCI standard has expanded into 3 separate and related standards: 
- *Runtime*: how to configure and execute a container.
- *Image*: how to package configuration, filesystem layers, and manifests.
- *Distribution*: how to transfer images and other content through registries, based on Docker’s Registry HTTP API V2.

The OCI registry is a simple `key.value` store, with the key being the hash/digest of the stored object (current convention is to use SHA256 for hashing). The data is stored as binary so can support anything you wish.  

OCI standardises the format for Manifest files that store the details of an object and how they relate to other objects. A manifest file entry has three essential parts, the `digest`, `size` and the `mediaType` or the target object. Using these three elements a tool can pull a the correct number of bytes for an object from the registry using the `digest` key and know what those bytes represent based on the `mediaType`.

One example of an OCI tool is the Docker CLI. Each command will 



# Making a simple container
To understand how they all work lets start by making a container. The below is the contents for the `dockerfile`
```dockerfile
FROM alpine:3.22
CMD echo 'hello world!'
```

We can instruct docker to build the image using the OCI specification and output the container to a directory using the following
```bash
docker build . \
  --file "dockerfile" \
  --platform "linux/arm64" \
  --tag "hello-world:v1" \
  --provenance=false \
  --sbom=false \
  --output "type=oci,tar=false,dest=./_output/hello-world"
```
The current `./_output` directory has the following structure (the command above uses `hello-world` as its output directory instead of `hello-world-oci`):

```text
_output/
`-- hello-world/
    |-- index.json
    |-- oci-layout
    `-- blobs/
        `-- sha256/
            |-- 3758bbde04ad2177b5c22b3fa378daad71b77636c383ca4c16fdca2f12c7cb4b
            |-- a5a08aa603fb886d94892aeb26a33acc1568d24c0e2c291ce5b621680b020f67
            `-- fea5b91588ca539ff8a89d7d5df6c6d65d6ab7bd89145ba57f32c302cf02ffbe
```

Next we look at the structure of the file `index.json`
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:3758bbde04ad2177b5c22b3fa378daad71b77636c383ca4c16fdca2f12c7cb4b",
      "size": 480,
      "annotations": {
        "io.containerd.image.name": "docker.io/library/hello-world:v1",
        "org.opencontainers.image.created": "2026-11-15T22:19:30Z",
        "org.opencontainers.image.ref.name": "v1"
      },
      "platform": { "architecture": "arm64", "os": "linux" }
    }
  ]
}
```
When we are decoding the contents of a manifest file we need to look at the various `mediaTypes`. The table below details some of this defined in the OCI standard.

| Purpose | OCI mediaType |
| --- | --- | --- |
| Single-image manifest | `application/vnd.oci.image.manifest.v1+json` |
| Image configuration | `application/vnd.oci.image.config.v1+json` |
| Gzip-compressed filesystem layer | `application/vnd.oci.image.layer.v1.tar+gzip` |
| Image Index / Multi-platform manifest list | `application/vnd.oci.image.index.v1+json` |

We see that the `index.json` file is an Image Index. For our container there is just one manifest in the manifest list. The single manifest entry has it's own `mediaType`, telling us it's reference to a Single-Image manifest, `platform` details telling use what platform this image supports (In my can this was build on an `arm64` processor) and some `annotations` containing some metadata.

The important value is the `digest`. This is simply the `sha256` value of the underlaying object, but is also used to locate the item in a OCI registry. Open the `_output/hello-world/blobs/sha256/` directory and look for an item that has a matching name as the value of the `digest`. Below is an example of the files contents (your digests may be different).

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
Looking at this `mediaType` of this manifest, we see it is a `Single Image Manifest`. As laid out the the OCI standard, this file must container a `config` and multiple `layers`. The `digest` value of the `config` and single `layer` point to the other two files in the `blobs/sha256` directory. You will find that the `config` is a json file of metadata and the `layer` is a `tar.gzip` binary file. If you are interested to see the layers contents, change the file extensions of the `layer` to end in `tar.gzip` the explode the file using the following
```bash
mkdir -p ./_output/extracted-layer
tar -xzf "./_output/hello-world-oci/blobs/sha256/fea5b91588ca539ff8a89d7d5df6c6d65d6ab7bd89145ba57f32c302cf02ffbe.tar.gzip" \
  -C "./_output/extracted-layer"
```
You will the the file looks very simliar to and operating system layout as that is exactly what it is. The layer is the contents of the docker container `alpine:3.22` we used as the base for our container.

## Multi Layer file.
Our test container only had a single layer because it was a very simple example. If the `dockerfile` was more complex, we would see more layers. Each is layer is applied in order and corresponds to a file system change applied to the previous layer.  If our `dockerfile` contain any of the following instructions we would expect to see each on as a container layer.

| Instruction |	Effect |
| --- | --- |
| FROM	| Uses the base image’s existing layers |
| RUN	| Usually creates a layer containing filesystem changes |
| COPY, ADD | Usually create a layer containing added files |

Each layer will be compress as `.tar.gzip` and have the mediaType `application/vnd.oci.image.layer.v1.tar+gzip`.

## Multi Platform Containers
Our simple container was built to run on our device. It will only suppport our processor and operating system. If we want to build a container that supports more operating systems we can create a build pipeline that compiles the container for multiple device. How we do this is outside the scope of this tutorial. 

Lets look at an existing OCI repository to see what a Multi-Platorm build looks like. We will be using `ghcr.io/stefanprodan/podinfo:6.17.0`. The docker file used to build the container can be found [here](https://github.com/stefanprodan/podinfo/blob/v6.x/Dockerfile). We can query the manifest for this container user the command below.
```bash
docker manifest inspect ghcr.io/stefanprodan/podinfo:6.17.0
```
Output:
```json
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.oci.image.index.v1+json",
   "manifests": [
      {
         "mediaType": "application/vnd.oci.image.manifest.v1+json",
         "size": 1816,
         "digest": "sha256:4e6ef1224e558caa7feffd577b3cbe76369d8ee43ef42bf800f173d3fef261a1",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.oci.image.manifest.v1+json",
         "size": 1816,
         "digest": "sha256:c59a38c0a430f2c4688a8d5af70e08ed04bc0b26dd0097e4117469c7e5968d67",
         "platform": {
            "architecture": "arm64",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.oci.image.manifest.v1+json",
         "size": 1111,
         "digest": "sha256:13a55bb0c5fbb60e4b43592c6c7feb043a268aeaff355a99d2a991956bdc458f",
         "platform": {
            "architecture": "unknown",
            "os": "unknown"
         }
      },
      {
         "mediaType": "application/vnd.oci.image.manifest.v1+json",
         "size": 1111,
         "digest": "sha256:83db6e6c1a3b8acd864758313815d0fb4b7e257f49788312865fea7ca1461d5e",
         "platform": {
            "architecture": "unknown",
            "os": "unknown"
         }
      }
   ]
}
```
Breaking down this manifest you see it's an Image Index containing a list of references to multiple Single Manifest documents for different Processor architectures and OS. We can query each on one of these entries using the following command with the appropriate hash.
```bash
docker manifest inspect ghcr.io/stefanprodan/podinfo@sha256:c59a38c0a430f2c4688a8d5af70e08ed04bc0b26dd0097e4117469c7e5968d67
```
Ouput
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
          "mediaType": "application/vnd.oci.image.config.v1+json",
          "digest": "sha256:f86f68d24ba57fe73657379025a0f5274cbfa86a5921726cdb8320b06f512bcf",
          "size": 3738
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:d3531b7a4f217bdc3426c57bcff84c170f086f456a39689d4a615c6d026c4be0",
      "size": 4190488
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:c350b7085d431e71de1265a6089c0292f478dd77f30dfae79c830de0b2911767",
      "size": 2816243
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1",
      "size": 32
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:dd074ddc4ec1c38fdfdfcdde957adf9a59a78771d9504b2f21cf80f94f3a7758",
      "size": 10755331
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:3a84628cfcc37f6d1409747e22d938e0c4a41c947a88da806309b04780345234",
      "size": 5062507
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:6b0b6f7fdd67eb2f4db77a00522d2329ca8d59798119b5697c0de0f37356dde4",
      "size": 2133
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:1d99b3acb206bffebe87f7d1809e101ebcf1652138f09712c59c5d121922fd9d",
      "size": 1198
    },
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:0eee9ce505051b8e093169e678c11d030e4f9327df4c44313846cdc470ca49d3",
      "size": 10759708
    }
  ]
}
```

# OCI Summary
The OCI standard allows tools to understand the contents of an OCI registry and perform actions based on what it find there. The address of any object is simply the SHA256 of the data contained within. The type of data does not matter as the content is just binary. 


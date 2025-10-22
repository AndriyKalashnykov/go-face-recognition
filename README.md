[![Hits](https://hits.sh/github.com/AndriyKalashnykov/go-face-recognition.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/go-face-recognition/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/go-face-recognition)
# go-face-recognition

Go-Face-Recognition is an facial recognition system, based on the principles of FaceNet and developed entirely in Go language. It leverages cutting-edge technology and utilizes the go-face library, which is built upon the powerful dlib C++ library for high-performance facial analysis.

## Table of Contents

- [Overview](#overview)
  - [About FaceNet](#about-facenet)
  - [About dlib](#about-dlib)
- [Key Features](#key-features)
- [Usage](#usage)
  - [Dynamic Loading of People](#dynamic-loading-of-people)
  - [Recognition of Faces](#recognition-of-faces)
  - [Output Generation](#output-generation)
  - [Capabilities](#capabilities)
- [Installation and Usage](#installation-and-usage)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## About FaceNet

Go-Face-Recognition is based on the principles of [FaceNet](https://arxiv.org/abs/1503.03832), a groundbreaking facial recognition system developed by Google. FaceNet employs a deep neural network to directly learn a mapping from facial images to a compact Euclidean space, where distances between embeddings correspond directly to a measure of facial similarity. By leveraging this learned embedding space, tasks such as facial recognition, verification, and clustering become straightforward, as FaceNet embeddings serve as feature vectors that capture essential facial characteristics. This integration enables Go-Face-Recognition to achieve state-of-the-art performance in facial recognition tasks, making it a versatile and powerful tool for various applications.

### About dlib

[dlib](http://dlib.net/) is a modern C++ toolkit containing machine learning algorithms and tools for creating complex software in C++ to solve real-world problems. It is renowned for its robustness, efficiency, and versatility in various applications, including computer vision, machine learning, and artificial intelligence.

## Key Features

- **Dynamic Person Loading:** Go-Face-Recognition dynamically loads people from within the 'persons' directory, enhancing flexibility.

- **Precise Face Recognition:** Utilizing go-face library powered by dlib, the system performs accurate and reliable face recognition, even in complex scenarios.

- **Easy Deployment with Docker:** To streamline dependency management and deployment, the project is encapsulated within a Docker environment, ensuring seamless integration into any development or production environment.

This project relies on own Docker image of DLib - [dlib-docker](https://github.com/AndriyKalashnykov/dlib-docker)
## Usage

### Dynamic Loading of People

This project dynamically loads people from within the `persons/` directory. Each person should have a subfolder with the person's name, containing images of that person to be used in the model. It is ideal to provide more than one image per person to improve classification accuracy. The images provided for each person should contain only one face, which is the face of the person.

### Recognition of Faces

After loading the people, the software reads an image from the `images/` directory. By default, it searches for an image named `unknown.jpg`. It then recognizes the faces in the image based on the provided people. The input image can contain multiple people, and the software attempts to recognize all of them.

### Output Generation

The output of the system is a new image with the faces marked and the name of each identified person. The generated image will be saved in the `images/` directory with the name `result.jpg`.

### Capabilities

The system enables effortless recognition of faces within images, empowering users with a powerful tool for various applications, including security, authentication, access control, and more.

## Installation and Usage

### Clone this repository

```bash
git clone https://github.com/AndriyKalashnykov/go-face-recognition.git
```

### Navigate to the project directory:

```bash
cd go-face-recognition
```

### Build & Run Docker image

#### amd64

```bash
BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face:v0.0.2
IMG=andriykalashnykov/go-face-recognition:latest-go-face
docker buildx build --load --platform linux/amd64 -f Dockerfile.go-face --build-arg BUILDER_IMAGE=$BUILDER_IMAGE -t $IMG .
docker run -it --rm --platform linux/amd64 $IMG /bin/sh
uname -m
./main
```

#### arm64

```bash
BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face:v0.0.2
IMG=andriykalashnykov/go-face-recognition:latest-go-face
docker buildx build --load --platform linux/arm64 -f Dockerfile.go-face --build-arg BUILDER_IMAGE=$BUILDER_IMAGE -t $IMG .
docker run -it --rm --platform linux/arm64 $IMG /bin/sh
uname -m
./main
```

#### arm/v7

```bash
BUILDER_IMAGE=ghcr.io/andriykalashnykov/go-face:v0.0.2
IMG=andriykalashnykov/go-face-recognition:latest-go-face
docker buildx build --load --platform linux/arm/v7 -f Dockerfile.go-face --build-arg BUILDER_IMAGE=$BUILDER_IMAGE -t $IMG .
docker run -it --rm --platform linux/arm/v7 $IMG /bin/sh
uname -m
./main
```

### Download & Run the Docker image

#### amd64
```bash
IMG=ghcr.io/andriykalashnykov/go-face-recognition:v0.0.2
docker pull $IMG
docker run -it --rm --platform linux/amd64 $IMG /bin/sh
uname -m
./main
````

#### arm64
```bash
IMG=ghcr.io/andriykalashnykov/go-face-recognition:v0.0.2
docker pull $IMG
docker run -it --rm --platform linux/arm64 $IMG /bin/sh
uname -m
./main
````

#### arm/v7
```bash
IMG=ghcr.io/andriykalashnykov/go-face-recognition:v0.0.2
docker pull $IMG
docker run -it --rm --platform linux/arm/v7 $IMG /bin/sh
uname -m
./main
````

### Building on MacOS

Install OpenBLAS etc: 

```bash
brew tap messense/macos-cross-toolchains
brew install aarch64-unknown-linux-musl
brew install messense/macos-cross-toolchains/aarch64-unknown-linux-gnu
brew link openblas 2>&1
```

Install dlib:
```bash
brew install cmake
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir build
cd build
cmake ..
cmake --build . --config Release
sudo make install
```

run the following command:

```bash
make build-arm64
./cmd/main
```

## Project Structure

The `images/` directory contains the input and output images. The `persons/` directory contains sub-folders for each person, with images of that person to be used in the model. The `models/` directory contains the trained model for facial recognition. The `internal/` directory contains the core logic of the system, including entities and use cases. The `cmd/` directory contains the main entry point of the system.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvement, please open an issue or submit a pull request on the GitHub repository.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

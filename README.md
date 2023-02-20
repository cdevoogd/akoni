# Akoni
Akoni is a custom build of the [Iosevka typeface](https://github.com/be5invis/Iosevka) licensed under the SIL Open Font License v1.1.

## Installing Akoni

### Homebrew Cask
If you are on macOS and use Homebrew, you can install Akoni and its Nerd Font variant as a Homebrew Cask:

```shell
brew install --cask cdevoogd/tap/font-akoni
brew install --cask cdevoogd/tap/font-akoni-nerd-font
# or
brew tap cdevoogd/tap
brew install --cask font-akoni
brew install --cask font-akoni-nerd-font
```

### GitHub Releases
Download the latest release from the [releases page](https://github.com/cdevoogd/akoni/releases), unzip the archive, and install the font.

## Building Akoni
The repository contains a build script that can be used to build Akoni and patch it with the Nerd Fonts patcher. To run all steps in the process, you will need a few dependencies:
* Docker
* `zip`
* `unzip`

Once you have those, you can clone the repository and run the `build.sh` script in the root of the repository. Note that this will take quite a bit and can be very resource intensive. There are some options you can pass to limit the number of parallel processes or to only perform specific steps of the build process (run `build.sh --help` for more information).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2019-10-16

### Fixed

- [Zap.Directory] Reverse the order of file headers in the central directory.
  This allows naive tools (like Archive Utility on MacOS) to correctly extract
  the zip.

- [Zap.Entry] Correct the general purpose bit flag, it must be `8` and not
  `0x008`. This allows unarchiving utilities to correctly extract files from the
  archive.

## [0.1.0] - 2019-10-07

- [Zap] Initial release with base functionality.

[Unreleased]: https://github.com/sorentwo/oban/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dscout/zap/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dscout/zap/compare/6bd6567...v0.1.0

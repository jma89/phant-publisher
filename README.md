# phant-publisher
Uploads executable files to a Phant server for distribution. Written in Autoit.

This application is still very rough around the edges, but provides a simple command-line interface for quickly uploading updated binaries for projects to a Phant server. This can be useful as a mechanism to distribute updates to clients without hosting a traditional web server. Files are encrypted using AES and then converted using Base64 before being split into chunks and uploaded.

Future plans include switching this order (Base64, then AES) to take advantage of block-level change distribution. This would provide the framework for providing clients with only the changed portions of a binary so it can be updated without having to download the entire file all over again.

Phant Publisher is released under the Adaptive Publice License 1.0. A summary of this license may be found at TL;DR Legal: https://tldrlegal.com/license/adaptive-public-license-1.0-%28apl-1.0%29

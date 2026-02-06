# README

[![Build Status](https://travis-ci.org/joelakes/TCD-Hyrax-Web-App.svg?branch=master)](https://travis-ci.org/joelakes/TCD-Hyrax-Web-App)

## Local Setup

In order for the Universal Viewer to work properly locally, run the following:
```sh
yarn install
```

### Docker Setup

Refer to the [ops README](ops/README.md).

---

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Rails version:
  - 5.1.6 (Hyrax didn't work with 5.2.1)

* Ruby version:
  - 2.5.1

* System dependencies/Hyrax prerequisites:
  - Imagemagick (I had to add jpg delegate)
  - Fits 1.3.0
  - LibreOffice
  - Fedora Commons 4.7.5
  - MySql (defaults to SqlLite without it)
  - Solr 7.5.0 (needed to clone solr_wrapper config to set up Core)
  - Redis (also needs tcl)
  - ffmpeg

* Configuration
  -

* Database creation
  -

* Database initialization
  -

* How to run the test suite:
  - rake hydra:test_server
  - rspec spec

* Services (job queues, cache servers, search engines, etc.)
  - Search engine is SOLR
  -

* Deployment instructions
  -

* ...

* ... etc


### IIIF URL configuration

If you set `EXTERNAL_IIIF_URL` in your environment, then IiifPrint will use that URL as the root for your IIIF URLs. It will also switch from using the file set ID to using the SHA1 of the file as the identifier. This enables using serverless_iiif or Cantaloupe (refered to as the service) by pointing the service to the same S3 bucket that FCREPO writes the uploaded files to. By setting it up that way you do not need the service to connect to FCREPO or Hyrax at all, both natively support connecting to an S3 bucket to get their data.

For Trinity production to use cataloupe in a similar way, set the `EXTERNAL_IIIF_URL` to https://digitalcollections.tcd.ie/iiif/2

Cantaloupe property changes:

delegate_script.enabled = false
source.static = FilesystemSource
FilesystemSource.BasicLookupStrategy.path_prefix = /digicolapp/repository/fedora01/fcrepo.binary.directory

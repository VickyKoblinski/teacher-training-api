This is documentation for the Department for Education (DfE)’s postgraduate
teacher training course information API.

## API Status

In the process of being implemented. Parts may work, but it will not match the
documentation here.

## What this API is for

Retrieving information about postgraduate teacher training courses.

## Codes and reference data

DfE Apply will avoid prioprietary codes wherever possible, preferring existing
data formats such as ISO-certified standards or HESA codes.

Codes appear in three contexts:

- All dates in the API specification are intended to be [ISO
  8601](https://www.iso.org/iso-8601-date-and-time-format.html) compliant

## How do I connect to this API?

### Authentication and authorisation

The API is open to the public and does not require authentication.

### Versioning

The version of the API is specified in the URL `/api/public/v{n}/`. For example:
`/api/public/v1/`.

When the API changes in a way that is backwards-incompatible, a new version
number of the API will be published.

When a new version, for example `/api/public/v2`, is published, both the
previous **v1** and the current **v2** versions will be supported. However we
will only support up-to one version back, so if the **v3** is published, the
**v1** will be discontinued.

When non-breaking changes are made to the API, this will not result in a version
bump. An example of a non-breaking change could be the introduction of a new
field without removing an existing field.

Information about deprecations (for instance attributes/endpoints that will be
modified/removed) will be included in the API response through a ‘Warning’
header.

We will update our [release notes](/api-docs/release-notes) with all breaking
and non-breaking changes.

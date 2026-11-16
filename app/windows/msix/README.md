# The MSIX signing certificate

`kallo-msix.cer` is the public half of the self-signed certificate that signs
the Windows MSIX in `.github/workflows/release.yml`. Its subject is `CN=Kallo`,
and it carries the code-signing extended key usage. A Windows user imports it
once (double-click → *Local Machine* or *Current User* → **Trusted People**) and
then installs `kallo-desktop-windows-x86_64.msix`; later releases signed with
the same certificate update the app in place.

The private half is not in this repository. The PFX (base64) and its password
live in the repository secrets `MSIX_CERT_PFX` and `MSIX_CERT_PASSWORD`; the
release workflow reads them to run `dart run msix:create`.

The certificate was made with OpenSSL:

```bash
openssl req -x509 -newkey rsa:3072 -sha256 -days 3650 -nodes \
  -keyout kallo-msix-key.pem -out kallo-msix-cert.pem \
  -subj "/CN=Kallo" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning"
openssl pkcs12 -export -legacy -out kallo-msix.pfx \
  -inkey kallo-msix-key.pem -in kallo-msix-cert.pem \
  -name "Kallo"
openssl x509 -in kallo-msix-cert.pem -outform DER -out kallo-msix.cer
```

The `-legacy` flag writes the older PKCS#12 encryption that `signtool` on the
Windows runner reads without extra providers. Replacing the certificate means
replacing both secrets and committing the new `.cer`; the package identity
(`CN=Kallo`) should stay the same so MSIX updates keep working.

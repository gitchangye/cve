cve-2021-3449: main.go $(wildcard tls/*.go)
	go build -o cve-2021-3449 .

.ONESHELL:
demo-openssl: cve-2021-3449
	$(MAKE) -C demo start-openssl
	./cve-2021-3449 -host localhost:4433
	$(MAKE) -C demo stop-openssl

.ONESHELL:
demo-apache: cve-2021-3449
	$(MAKE) -C demo start-apache
	./cve-2021-3449 -host localhost:443
	sleep 5
	$(MAKE) -C demo stop-apache

.ONESHELL:
demo-nginx: cve-2021-3449
	$(MAKE) -C demo start-nginx
	./cve-2021-3449 -host localhost:4433
	sleep 3
	$(MAKE) -C demo stop-nginx

clean:
	rm -f cve-2021-3449
	$(MAKE) -C demo clean
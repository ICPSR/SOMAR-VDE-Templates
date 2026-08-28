# Squid Proxy Docker Container


## Configuration

### `squid.conf`
Configures Squid to:
- Deny all outbound requests by default
- Only allow access to domains listed in `sites.allowlist.txt`
- Restrict access to safe ports (`80`, `443`)
- Log traffic to syslog

### `sites.allowlist.txt`
A list of allowed domains. For example, to allow PyPI and CRAN.


## Usage

### Build the image:

docker build -t squid-allowlist-proxy .

### Run the container

docker run -d --name squid-proxy -p 3128:3128 squid-allowlist-proxy
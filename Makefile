TAG_VERSION=oc1.0.0  # TODO: Do something less dumb than this

build: api client

api:
	docker build -t curriki/api:${TAG_VERSION} -f Dockerfile.api .
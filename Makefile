# Hugo Blog Makefile

.PHONY: sync serve build clean

sync:
	./sync_obsidian_to_hugo.sh

serve: sync
	hugo server -D

build: sync
	hugo --minify

clean:
	rm -rf public
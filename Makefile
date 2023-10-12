
### Coq website : generation of static pages ###

DST:=dest
PP:=yamlpp-0.3/yamlpp
INCLS:=incl/header.html incl/footer.html incl/news/recent.html incl/macros.html
DEPS:=$(INCLS) $(PP)

all: pages news conf assets

aliases: newsaliases

clean:
	rm -rf $(DST)/*
	rm -rf .*.stamp
	rm -f incl/news/recent.html
	rm -f $(PP) $(PP).cm* $(PP).o

## In case we need to regenerate yamlpp.ml from its .mll.

$(PP).ml: $(PP).mll
	ocamllex $<

$(PP): $(PP).ml
	ocamlopt -o $@ $<
	chmod +x $@

.PHONY: all pages news conf assets newsaliases clean

## We generate html pages from all .html files in pages

PAGES:= $(shell find pages -name *.html)
PAGESDST:=$(patsubst pages/%,$(DST)/%, $(PAGES))

pages: $(PAGESDST)

$(DST)/%: pages/% $(DEPS)
	mkdir -p $(dir $@) && $(PP) $< -o $@

## Page aliases through Apache RewriteRule...

conf: $(DST)/aliases.conf

# L flags are needed because we don't want to add a .html suffix to the
# original requested URL if it has been rewritten. Note after an L rule is
# triggered, another pass of rewriting will be performed on the new URL
# unless we specify E=END.

$(DST)/aliases.conf: NEWSINDEX aliases.footer.conf
	sed -n -e "s|\(..*\):\(.*\)|RewriteRule ^news/\2$$ /news/\1.html [E=END:1,L]|p" NEWSINDEX > $@
	sed -n -e "s|\(..*\):\(.*\)|RewriteRule ^news/\1$$ /news/\2 [L,R=301]|p" NEWSINDEX >> $@
	sed -n -e "s|\(..*\):\(.*\)|RewriteRule ^\2$$ /news/\2 [L,R=301]|p" NEWSINDEX >> $@
	cat aliases.footer.conf >> $@

assets: $(DST)/styles \
	$(DST)/sites \
	$(DST)/modules \
	$(DST)/files \
	$(DST)/scripts \
	$(DST)/coq-workshop/files

$(DST)/files:
	cp -r files $@

$(DST)/styles:
	cp -r styles $@

$(DST)/sites:
	cp -r sites $@

$(DST)/modules:
	cp -r modules $@

$(DST)/scripts:
	cp -r scripts $@

$(DST)/coq-workshop/files: 
	mkdir -p $(dir $@) && cp -r files $@

## News, listed in the NEWSINDEX file

NEWS:= $(shell cat NEWSINDEX)

RECENTNEWS:= $(shell head -n 3 NEWSINDEX)

NEWSSRC:=$(addprefix news/,$(NEWS))
NEWSDST:=$(patsubst %,$(DST)/news/%.html,$(NEWS))

news: $(DST)/news/index.html $(DST)/rss.xml $(NEWSDST)

incl/news/recent.html: NEWSINDEX Makefile $(PP) $(addprefix news/,$(RECENTNEWS))
	$(PP) -o $@ $(patsubst %,news/% incl/news/li.html,$(RECENTNEWS))

$(DST)/news/index.html: NEWSINDEX $(NEWSSRC) $(DEPS) incl/news/item.html incl/news/title.html
	mkdir -p $(dir $@)
	$(PP) -o $@ \
          incl/news/title.html \
          incl/header.html \
          $(patsubst %,% incl/news/item.html,$(NEWSSRC)) \
          incl/footer.html

$(DST)/news/%.html: news/% $(DEPS) incl/news/solo.html
	mkdir -p $(dir $@)
	$(PP) $< incl/news/solo.html -o $@

$(DST)/rss.xml: $(NEWSSRC) incl/rss/header.xml incl/rss/footer.xml incl/rss/item.xml $(PP)
	$(PP) -o $@ \
          incl/rss/header.xml \
          $(patsubst %,% incl/rss/item.xml,$(NEWSSRC)) \
          incl/rss/footer.xml

newsaliases: .newsaliases.stamp

.newsaliases.stamp: NEWSINDEX
	IFS=':'; while read a b; \
	do [ -n "$$b" ] && mkdir -p $(DST)/news/$$b && \
	cp ../$$a.html $(DST)/news/$$b/index.html; \
	done < NEWSINDEX; touch $@

printenv:
	@echo "### PAGES ###"
	@echo $(PAGES) | tr " " "\n"
	@echo "### NEWS ###"
	@echo $(NEWS) | tr " " "\n"

# Needs python 2.x (this exists also for python 3, with a different syntax)
run: aliases
	@echo "Starting a local web server for test"
	@echo "It is accessible at: http://localhost:8000"
	cd $(DST) && (python3 ../srv/server.py)

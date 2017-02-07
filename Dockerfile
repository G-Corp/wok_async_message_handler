FROM jonathanperret/elixir:1.4.0
MAINTAINER piotr.kedziora@botsunit.com

RUN apt-get update && apt-get -y install postgresql-client erlang-src

COPY . /app
WORKDIR /app

CMD ["make", "-fMakefile.tasks"]

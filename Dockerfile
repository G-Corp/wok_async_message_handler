FROM jonathanperret/elixir:1.2.6
MAINTAINER piotr.kedziora@botsunit.com

RUN apt-get update && apt-get -y install postgresql-client erlang-src

COPY . /app
WORKDIR /app

CMD ["make", "-fMakefile.tasks"]

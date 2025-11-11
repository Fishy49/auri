FROM ruby:3.2-alpine

RUN apk add --no-cache build-base sqlite-dev

WORKDIR /app

COPY Gemfile ./
RUN bundle install --without development test

COPY . .

EXPOSE 4567

CMD ["ruby", "app.rb", "-o", "0.0.0.0"]

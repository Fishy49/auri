# Auri - A Day Journal

A minimalist micro-journal inspired by Auri from Patrick Rothfuss's "The Slow Regard of Silent Things". Record what kind of day today is in a word or two, with a few notes about how it feels.

<p align="center"><img width="805" height="838" alt="image" src="https://github.com/user-attachments/assets/7061e788-dbc1-419c-8fd2-1c2176c5d24e" /></p>


## What It Does

- Define each day with a simple word or phrase (Mending, Making, Exploring, etc.)
- Add optional notes about your day
- View your recent days at a glance
- Beautiful, calming interface with warm amber tones
- All data stored locally in SQLite

## Installation

1. Make sure you have Ruby installed (Ruby 3.0+ recommended)

2. Install dependencies:
   ```bash
   bundle install
   ```

## Running Locally

Start the server:
```bash
ruby app.rb
```

Or use Rackup:
```bash
rackup
```

Then visit `http://localhost:4567` in your browser.

## Deployment Options

### Option 1: Deploy to Fly.io (Recommended - Free Tier Available)

1. Install the Fly CLI: https://fly.io/docs/hands-on/install-flyctl/

2. Create a `fly.toml` in your project:
   ```toml
   app = "auri-journal"
   primary_region = "sjc"

   [build]

   [http_service]
     internal_port = 4567
     force_https = true
     auto_stop_machines = true
     auto_start_machines = true
     min_machines_running = 0

   [[vm]]
     memory = '256mb'
     cpu_kind = 'shared'
     cpus = 1
   ```

3. Create a `Dockerfile`:
   ```dockerfile
   FROM ruby:3.2-alpine

   RUN apk add --no-cache build-base sqlite-dev

   WORKDIR /app

   COPY Gemfile Gemfile.lock ./
   RUN bundle install --without development test

   COPY . .

   EXPOSE 4567

   CMD ["ruby", "app.rb", "-o", "0.0.0.0"]
   ```

4. Deploy:
   ```bash
   fly launch
   fly deploy
   ```

### Option 2: Run on a VPS (DigitalOcean, Linode, etc.)

1. SSH into your server
2. Clone/upload your code
3. Install Ruby and Bundler
4. Run `bundle install`
5. Use systemd or supervisor to keep it running:

Example systemd service (`/etc/systemd/system/auri.service`):
```ini
[Unit]
Description=Auri Day Journal
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/path/to/auri
ExecStart=/usr/bin/ruby app.rb -o 0.0.0.0 -p 4567
Restart=always

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable auri
sudo systemctl start auri
```

### Option 3: Heroku

1. Create a `Procfile`:
   ```
   web: bundle exec rackup -p $PORT
   ```

2. Deploy:
   ```bash
   heroku create your-auri-journal
   git push heroku main
   ```

## Data Storage

All journal entries are stored in `auri.db` (SQLite database) in the application directory. Back this up regularly if you want to preserve your journal entries.

## Customization

The app uses Tailwind CSS via CDN for styling. Colors and fonts can be easily customized in the `<style>` section of `app.rb`:

- Main color scheme: Amber tones (warm, comforting)
- Font: Crimson Text (elegant serif)

## Philosophy

Like Auri herself, this app believes in simplicity and finding the right place for things. Each day has its own nature - some are for mending, some for making, some for exploring. By naming our days, we honor their unique character.

"Everything has a place where it belongs."

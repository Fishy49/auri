require 'sinatra'
require 'sqlite3'
require 'json'
require 'date'

# Database setup
def db
  @db ||= SQLite3::Database.new('auri.db')
  @db.results_as_hash = true
  @db
end

# Initialize database
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS days (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    day_type TEXT NOT NULL,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
SQL

# Create index on date for faster lookups
db.execute "CREATE INDEX IF NOT EXISTS idx_days_date ON days(date);"

# Routes
get '/' do
  # Get date from params or default to today
  @current_date = params[:date] ? Date.parse(params[:date]) : Date.today
  @current_date_str = @current_date.to_s

  # Find previous entry date (most recent date before current date that has an entry)
  prev_entry = db.execute("SELECT date FROM days WHERE date < ? ORDER BY date DESC LIMIT 1", [@current_date_str]).first
  @prev_date = prev_entry ? prev_entry['date'] : nil

  # Find next entry date (earliest date after current date that has an entry)
  # OR if no next entry exists and current date is before today, use today
  next_entry = db.execute("SELECT date FROM days WHERE date > ? ORDER BY date ASC LIMIT 1", [@current_date_str]).first
  if next_entry
    @next_date = next_entry['date']
  elsif @current_date < Date.today
    @next_date = Date.today.to_s
  else
    @next_date = nil
  end

  # Get entry for current date
  @current_entry = db.execute("SELECT * FROM days WHERE date = ? ORDER BY id DESC LIMIT 1", [@current_date_str]).first
  @edit_mode = params[:edit] == 'true'
  erb :index
end

get '/all' do
  @page = (params[:page] || 1).to_i
  @per_page = 30
  @offset = (@page - 1) * @per_page

  @recent_days = db.execute("SELECT * FROM days ORDER BY date DESC LIMIT ? OFFSET ?", [@per_page, @offset])
  @total_entries = db.execute("SELECT COUNT(*) as count FROM days").first['count']
  @total_pages = (@total_entries.to_f / @per_page).ceil
  @day_type_stats = db.execute("SELECT day_type, COUNT(*) as count FROM days GROUP BY day_type ORDER BY count DESC LIMIT 10")

  erb :all
end

post '/day' do
  date = params[:date] || Date.today.to_s
  day_type = params[:day_type]&.strip
  notes = params[:notes]&.strip

  if day_type && !day_type.empty?
    # Check if entry exists for this date
    existing = db.execute("SELECT id FROM days WHERE date = ?", [date]).first

    if existing
      # Update existing entry
      db.execute(
        "UPDATE days SET day_type = ?, notes = ? WHERE date = ?",
        [day_type, notes, date]
      )
    else
      # Insert new entry
      db.execute(
        "INSERT INTO days (date, day_type, notes) VALUES (?, ?, ?)",
        [date, day_type, notes]
      )
    end
  end

  redirect "/?date=#{date}"
end

delete '/day/:id' do
  db.execute("DELETE FROM days WHERE id = ?", [params[:id]])
  redirect '/'
end

get '/export' do
  entries = db.execute("SELECT date, day_type, notes FROM days ORDER BY date ASC")
  content_type 'application/json'
  attachment "auri-export-#{Date.today}.json"
  JSON.pretty_generate(entries)
end

post '/import' do
  if params[:file] && params[:file][:tempfile]
    begin
      json_data = JSON.parse(params[:file][:tempfile].read)

      # Wipe out all existing entries
      db.execute("DELETE FROM days")

      # Import new entries
      json_data.each do |entry|
        db.execute(
          "INSERT INTO days (date, day_type, notes) VALUES (?, ?, ?)",
          [entry['date'], entry['day_type'], entry['notes']]
        )
      end

      redirect '/'
    rescue JSON::ParserError
      halt 400, "Invalid JSON file"
    end
  else
    halt 400, "No file provided"
  end
end

__END__

@@layout
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Auri - Days</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Crimson+Text:ital,wght@0,400;0,600;1,400&display=swap');

    body {
      font-family: 'Crimson Text', serif;
    }

    .day-type {
      text-transform: lowercase;
      font-style: italic;
    }

    details summary {
      cursor: pointer;
      user-select: none;
    }

    details summary::-webkit-details-marker {
      display: none;
    }
  </style>
</head>
<body class="bg-amber-50 min-h-screen">
  <%= yield %>
</body>
</html>

@@index
<div class="container mx-auto px-4 py-8 max-w-3xl">
  <!-- Header -->
  <div class="text-center mb-8">
    <h1 class="text-5xl font-semibold text-amber-900 mb-2">
      <a href="/" class="hover:text-amber-700 transition-colors">Auri</a>
    </h1>
    <p class="text-lg text-amber-700 italic">What kind of day is today?</p>
  </div>

  <!-- Date Navigation -->
  <div class="flex items-center justify-between mb-6">
    <% if @prev_date %>
      <a href="/?date=<%= @prev_date %>" class="text-3xl text-amber-600 hover:text-amber-700 transition-colors px-4 py-2">
        ←
      </a>
    <% else %>
      <span class="text-3xl text-amber-300 px-4 py-2">←</span>
    <% end %>
    <div class="text-lg font-semibold text-amber-900">
      <%= @current_date.strftime('%B %d, %Y') %>
    </div>
    <% if @next_date %>
      <a href="/?date=<%= @next_date %>" class="text-3xl text-amber-600 hover:text-amber-700 transition-colors px-4 py-2">
        →
      </a>
    <% else %>
      <span class="text-3xl text-amber-300 px-4 py-2">→</span>
    <% end %>
  </div>

  <!-- Current Date's Entry -->
  <% if @current_entry && !@edit_mode %>
    <!-- Display Card -->
    <div class="bg-white rounded-lg shadow-md p-8 mb-8 border border-amber-200">
      <div class="flex justify-end items-start mb-6">
        <a href="/?date=<%= @current_date_str %>&edit=true" class="text-amber-600 hover:text-amber-700 text-sm font-semibold transition-colors">
          Edit
        </a>
      </div>

      <div class="mb-6">
        <div class="text-amber-700 text-lg mb-2">
          <span class="italic"><%= @current_date == Date.today ? 'Today' : 'This' %> is a day for...</span>
        </div>
        <div class="text-4xl day-type text-amber-900 font-semibold">
          <%= @current_entry['day_type'] %>
        </div>
      </div>

      <% if @current_entry['notes'] && !@current_entry['notes'].empty? %>
      <div class="border-t border-amber-100 pt-6">
        <div class="text-amber-800 leading-relaxed">
          <%= @current_entry['notes'] %>
        </div>
      </div>
      <% end %>
    </div>
  <% else %>
    <!-- Entry Form -->
    <div class="bg-white rounded-lg shadow-md p-8 mb-8 border border-amber-200">
      <form method="POST" action="/day" class="space-y-6">
        <input type="hidden" name="date" value="<%= @current_date_str %>">

        <div>
          <label for="day_type" class="block text-lg text-amber-800 mb-2">
            <%= @current_date == Date.today ? 'Today' : 'This' %> is a <span class="italic">day for...</span>
          </label>
          <input
            type="text"
            id="day_type"
            name="day_type"
            value="<%= @current_entry ? @current_entry['day_type'] : '' %>"
            placeholder="Mending, Finding, Exploring..."
            class="w-full px-4 py-3 text-xl italic border-2 border-amber-300 rounded-lg focus:outline-none focus:border-amber-500 bg-amber-50/30"
            required
          >
        </div>

        <div>
          <label for="notes" class="block text-lg text-amber-800 mb-2">
            A few words...
          </label>
          <textarea
            id="notes"
            name="notes"
            rows="4"
            placeholder="Describe this day. Is it a white day? A deep day? A finding day?"
            class="w-full px-4 py-3 border-2 border-amber-300 rounded-lg focus:outline-none focus:border-amber-500 bg-amber-50/30 resize-none"
          ><%= @current_entry ? @current_entry['notes'] : '' %></textarea>
        </div>

        <button
          type="submit"
          class="w-full bg-amber-600 hover:bg-amber-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors duration-200"
        >
          <%= @current_entry ? 'Update Day' : 'Save Day' %>
        </button>
      </form>
    </div>
  <% end %>

  <!-- Link to All Entries -->
  <div class="text-center mt-8">
    <a href="/all" class="inline-block text-amber-600 hover:text-amber-700 font-semibold transition-colors border-b-2 border-amber-300 hover:border-amber-400 pb-1">
      View All Days
    </a>
  </div>

  <div class="text-center text-amber-600 text-sm mt-12 italic">
    <p>"Nothing is anything it shouldn't be."</p>
  </div>
</div>

@@all
<div class="container mx-auto px-4 py-8 max-w-3xl">
  <!-- Header -->
  <div class="text-center mb-8">
    <h1 class="text-5xl font-semibold text-amber-900 mb-2">
      <a href="/" class="hover:text-amber-700 transition-colors">Auri</a>
    </h1>
    <p class="text-lg text-amber-700 italic">All your days</p>
  </div>

  <!-- Back to Today Link -->
  <div class="text-center mb-8">
    <a href="/" class="inline-block text-amber-600 hover:text-amber-700 font-semibold transition-colors border-b-2 border-amber-300 hover:border-amber-400 pb-1">
      ← Back to Today
    </a>
  </div>

  <!-- All Days -->
  <% if @recent_days && @recent_days.any? %>
  <div class="mb-8">
    <h2 class="text-2xl font-semibold text-amber-900 mb-4">Your Days</h2>
    <div class="space-y-3">
      <% @recent_days.each do |day| %>
      <div class="bg-white rounded-lg shadow-sm p-5 border border-amber-100 hover:border-amber-300 transition-colors">
        <div class="flex justify-between items-start mb-2">
          <div class="flex-1">
            <div class="text-sm text-amber-600 mb-1">
              <%= Date.parse(day['date']).strftime('%B %d, %Y') %>
            </div>
            <div class="text-xl day-type text-amber-900 font-semibold">
              <%= day['day_type'] %>
            </div>
          </div>
          <div class="flex gap-2">
            <a href="/?date=<%= day['date'] %>&edit=true" class="text-amber-600 hover:text-amber-700 transition-colors text-sm">
              Edit
            </a>
            <form method="POST" action="/day/<%= day['id'] %>" class="inline">
              <input type="hidden" name="_method" value="DELETE">
              <button
                type="submit"
                onclick="return confirm('Delete this day?')"
                class="text-amber-400 hover:text-amber-600 transition-colors text-sm"
              >
                ✕
              </button>
            </form>
          </div>
        </div>
        <% if day['notes'] && !day['notes'].empty? %>
        <p class="text-amber-800 text-sm leading-relaxed mt-2 pl-0">
          <%= day['notes'] %>
        </p>
        <% end %>
      </div>
      <% end %>
    </div>
  </div>

  <!-- Pagination -->
  <% if @total_pages > 1 %>
  <div class="flex justify-center items-center gap-4 mt-8">
    <% if @page > 1 %>
      <a href="/all?page=<%= @page - 1 %>" class="text-amber-600 hover:text-amber-700 font-semibold transition-colors">
        ← Previous
      </a>
    <% else %>
      <span class="text-amber-300">← Previous</span>
    <% end %>

    <span class="text-amber-700">
      Page <%= @page %> of <%= @total_pages %>
    </span>

    <% if @page < @total_pages %>
      <a href="/all?page=<%= @page + 1 %>" class="text-amber-600 hover:text-amber-700 font-semibold transition-colors">
        Next →
      </a>
    <% else %>
      <span class="text-amber-300">Next →</span>
    <% end %>
  </div>
  <% end %>
  <% else %>
  <div class="text-center text-amber-700 italic">
    <p>No days recorded yet.</p>
  </div>
  <% end %>

  <!-- Patterns (Collapsible Stats) -->
  <% if @day_type_stats && @day_type_stats.any? %>
  <div class="mt-8 mb-8">
    <details class="bg-white rounded-lg shadow-sm border border-amber-100">
      <summary class="p-4 hover:bg-amber-50/50 transition-colors rounded-lg flex items-center justify-between">
        <span class="text-amber-700 text-sm italic">Patterns in your days...</span>
        <span class="text-amber-400 text-xs">▾</span>
      </summary>
      <div class="px-4 pb-4 pt-2">
        <div class="grid grid-cols-2 gap-3">
          <% @day_type_stats.each do |stat| %>
          <div class="flex justify-between items-baseline py-2 px-3 bg-amber-50/50 rounded">
            <span class="day-type text-amber-900"><%= stat['day_type'] %></span>
            <span class="text-amber-600 text-sm"><%= stat['count'] %></span>
          </div>
          <% end %>
        </div>
      </div>
    </details>
  </div>
  <% end %>

  <!-- Export/Import -->
  <div class="mt-8 mb-8">
    <details class="bg-white rounded-lg shadow-sm border border-amber-100">
      <summary class="p-4 hover:bg-amber-50/50 transition-colors rounded-lg flex items-center justify-between">
        <span class="text-amber-700 text-sm italic">Backup & Restore...</span>
        <span class="text-amber-400 text-xs">▾</span>
      </summary>
      <div class="px-4 pb-4 pt-2 space-y-4">
        <div>
          <a href="/export" class="inline-block w-full text-center bg-amber-600 hover:bg-amber-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors">
            Export All Entries (JSON)
          </a>
        </div>
        <div class="border-t border-amber-100 pt-4">
          <form method="POST" action="/import" enctype="multipart/form-data" class="space-y-3">
            <div>
              <label class="block text-sm text-amber-800 mb-2">
                Import Entries (Warning: This will replace all existing entries!)
              </label>
              <input
                type="file"
                name="file"
                accept=".json"
                required
                class="w-full text-sm text-amber-900 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-amber-100 file:text-amber-700 hover:file:bg-amber-200"
              >
            </div>
            <button
              type="submit"
              onclick="return confirm('This will DELETE all existing entries and replace them with the imported data. Are you sure?')"
              class="w-full bg-amber-800 hover:bg-amber-900 text-white font-semibold py-2 px-4 rounded-lg transition-colors"
            >
              Import & Replace All
            </button>
          </form>
        </div>
      </div>
    </details>
  </div>

  <div class="text-center text-amber-600 text-sm mt-12 italic">
    <p>"Nothing is anything it shouldn't be."</p>
  </div>
</div>

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
  @today = Date.today.to_s
  @today_entry = db.execute("SELECT * FROM days WHERE date = ? ORDER BY id DESC LIMIT 1", [@today]).first
  @recent_days = db.execute("SELECT * FROM days ORDER BY date DESC LIMIT 30")
  @day_type_stats = db.execute("SELECT day_type, COUNT(*) as count FROM days GROUP BY day_type ORDER BY count DESC LIMIT 10")
  erb :index
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

  redirect '/'
end

delete '/day/:id' do
  db.execute("DELETE FROM days WHERE id = ?", [params[:id]])
  redirect '/'
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
  <div class="text-center mb-12">
    <h1 class="text-5xl font-semibold text-amber-900 mb-2">Auri</h1>
    <p class="text-lg text-amber-700 italic">What kind of day is today?</p>
  </div>

  <!-- Today's Entry Form -->
  <div class="bg-white rounded-lg shadow-md p-8 mb-8 border border-amber-200">
    <form method="POST" action="/day" class="space-y-6">
      <input type="hidden" name="date" value="<%= @today %>">

      <div>
        <label class="block text-sm font-semibold text-amber-900 mb-2">
          Today is <%= Date.today.strftime('%B %d, %Y') %>
        </label>
      </div>

      <div>
        <label for="day_type" class="block text-lg text-amber-800 mb-2">
          This is a <span class="italic">day of...</span>
        </label>
        <input
          type="text"
          id="day_type"
          name="day_type"
          value="<%= @today_entry ? @today_entry['day_type'] : '' %>"
          placeholder="Mending, Making, Exploring..."
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
          placeholder="What does this day feel like?"
          class="w-full px-4 py-3 border-2 border-amber-300 rounded-lg focus:outline-none focus:border-amber-500 bg-amber-50/30 resize-none"
        ><%= @today_entry ? @today_entry['notes'] : '' %></textarea>
      </div>

      <button
        type="submit"
        class="w-full bg-amber-600 hover:bg-amber-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors duration-200"
      >
        <%= @today_entry ? 'Update Today' : 'Save Today' %>
      </button>
    </form>
  </div>


  <!-- Recent Days -->
  <% if @recent_days && @recent_days.any? %>
  <div class="mb-8">
    <h2 class="text-2xl font-semibold text-amber-900 mb-4">Recent Days</h2>
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
        <% if day['notes'] && !day['notes'].empty? %>
        <p class="text-amber-800 text-sm leading-relaxed mt-2 pl-0">
          <%= day['notes'] %>
        </p>
        <% end %>
      </div>
      <% end %>
    </div>
  </div>
  <% end %>

  <!-- Patterns (Collapsible Stats) -->
  <% if @day_type_stats && @day_type_stats.any? %>
  <div class="mb-8">
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

  <div class="text-center text-amber-600 text-sm mt-12 italic">
    <p>"Everything has a place where it belongs."</p>
  </div>
</div>

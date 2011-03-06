require "rubygems"
require "bundler"
Bundler.setup
Bundler.require

Sinatra::Base.root = File.join File.expand_path(File.join(File.dirname(__FILE__)))
Dir.glob(File.join(Sinatra::Base.root, 'models', '**/*.rb')).each { |f| require f }

DataMapper.setup :default, ENV['DATABASE_URL'] || 'sqlite3://pdx_pacman.db'
DataMapper.auto_upgrade!

class PdxPacman < Sinatra::Base
  
  GEOLOQI_OAUTH_TOKEN = 'ba1-138a8e75c1359c5d651120ca760ba8cce20b5f1d'  
  set :public, File.join(Sinatra::Base.root, 'public')
  
  get '/?' do
    erb :'index'
  end
  
  post '/trigger' do
    json = JSON.parse request.body
    @player = Player.first_or_create :geoloqi_id => json['user']['user_id']
    @player.profile_image = json['user']['profile_image']
    @player.name = json['user']['name']
    @player.save
    eat_dot json['place']['place_id']
    @player.add_points json['place']['extra']['points'] if json['place']['extra']['points']
    ''
  end
  
  get '/scores.json' do
    content_type 'application/json'
    players = Player.all.collect{|player| {:geoloqi_id => player.id, :score => player.points_cache, :name => player.name, :profile_image => player.profile_image}}
    players.to_json
  end
  
  get '/setup.json' do
    # var mockpellets  [ {id latitude longitude} ]
    
    pellets_raw = get_pellets
    
    json = JSON.parse get_pellets
    
    places = []
    
    json['places'].each do |place|
      unless place['extra']['active'] == '0'
        # latitude longitude place_id
        places << {:place_id => place['place_id'], :latitude => place['latitude'], :longitude => place['longitude']}
      end
    end
    places.to_json
  end
  
  post '/register' do
    
  end
  
  private
  # 
  def get_pellets
    request = Typhoeus::Request.new("https://api.geoloqi.com/1/place/list",
                          :body          => 'layer_id=10S',
                          :method        => :post,
                          :headers       => {'Authorization' => "OAuth #{GEOLOQI_OAUTH_TOKEN}"})
    hydra = Typhoeus::Hydra.new
    hydra.queue request
    hydra.run
    request.response.body
  end
  
  def eat_dot(place_id)
    Typhoeus::Request.new("https://api.geoloqi.com/1/place/update/#{place_id}",
                          :body          => {:extra => {:active => 0}}.to_json,
                          :method        => :post,  
                          :headers       => {'Authorization' => "OAuth #{GEOLOQI_OAUTH_TOKEN}", 'Content-Type' => 'application/json'})
    hydra = Typhoeus::Hydra.new
    hydra.queue request
    hydra.run
    request.response.body
  end
end
# encoding: utf-8
require 'sinatra'
require_relative 'suncalc.rb'
require 'date'
require 'tzinfo'
require 'open-uri'
require 'json'

helpers do
	def hue_to_rgb(p, q, t)
		t += 1 if t < 0
		t -= 1 if t > 1
		return p + (q - p) * 6 * t if t < 1.0/6
		return q if t < 1.0/2
		return p + (q - p) * (2.0/3 - t) * 6 if t < 2.0/3
		return p
	end

	def rbg_to_hex(i)
		i = (i * 255).round
		i = i.to_s(16)
		return i.length > 1 ? i : "0#{i}"
	end

	def hsl_to_hex(h, s, l)
		r = 0
		g = 0
		b = 0

		if s < 0.001
			r = g = b = l
		else
			q = l < 0.5 ? l * (1 + s) : l + s - l * s
			p = l * 2 - q
			r = hue_to_rgb(p, q, h + 1.0/3)
			g = hue_to_rgb(p, q, h)
			b = hue_to_rgb(p, q, h - 1.0/3)
		end

		r = rbg_to_hex(r)
		g = rbg_to_hex(g)
		b = rbg_to_hex(b)

		return "##{r}#{g}#{b}"
	end

	def get_ip(address)
		ip_info = open("http://ip-api.com/json/#{address}").read
		return JSON.parse(ip_info, {:symbolize_names => true})
	end
end

get '/' do
	@output = get_ip(request.ip)
	erb :solar
end

get '/analemma' do
	@output = get_ip(request.ip)
	erb :analemma
end

get '/analemma.svg' do
	latitude  = params[:latitude].nil?  ? 40.7127  : params[:latitude].to_f
	longitude = params[:longitude].nil? ? -74.0059 : params[:longitude].to_f
	timezone  = params[:timezone].nil?  ? "America/New_York" : params[:timezone]

	tz = TZInfo::Timezone.get(timezone)
	current = tz.current_period

	@output = Array.new
	x = Array.new
	y = Array.new
	
	time = Time.new(2016, 6, 1, 12, 0, 0, current.utc_offset)
	noon = SunCalc.get_times(time, latitude, longitude)
	noon = noon[:solar_noon]

	dates = (DateTime.new(2016, 1, 1)..DateTime.new(2017, 1, 1)).select {|d| d.monday? }
	dates.each_with_index do |date, i|
		time = Time.new(date.year, date.month, date.day, noon.hour, noon.min, noon.sec, current.utc_offset)

		position = SunCalc.get_position(time, latitude, longitude)
		position[:azimuth]  = ((position[:azimuth]  * (180/Math::PI)) - 360).abs
		position[:altitude] = ((position[:altitude] * (180/Math::PI)) - 360).abs
		position[:index] = date.cweek
		position[:date]  = date

		x << position[:azimuth]
		y << position[:altitude]

		@output << position
	end

	@output.each do |position|
		position[:azimuth]  -= x.min
		position[:altitude] -= y.min
	end

	@width  = (x.max - x.min + 10).round
	@height = (y.max - y.min + 10).round

	headers 'Content-Type' => "image/svg+xml"
	erb :analemma_svg
end

#!/usr/bin/ruby
# encoding: UTF-8
# Author: MaG
# http://newbieshell.blogspot.com/2012/07/esteganografia-el-canal-alfa.html

require 'chunky_png'
require 'getoptlong'

class IO
	def usage
		self.puts DATA.read()
	end
end

def get_available_size(image)
	size = 0
	for i in 0...image.width
		for j in 0...image.height
			size += 3 if ChunkyPNG::Color.a(image[i,j]).zero?
		end
	end
	size
end

def clean_image(image)
	for i in 0...image.width
		for j in 0...image.height
			image[i,j] = 0x00000000 if ChunkyPNG::Color.a(image[i,j]).zero?
		end
	end
end

def show_alpha(image)
	for i in 0...image.width
		for j in 0...image.height
			value = image[i,j]
			if ChunkyPNG::Color.a(value).zero?
				image[i,j] = value|0xFF
			end
		end
	end
end

def unhide_text(img)
	text = ''.force_encoding('binary')
	chars = []
	for i in 0...img.width
		for j in 0...img.height
			num = img[i,j]
			if ChunkyPNG::Color.a(num).zero?
				chars[0] = ChunkyPNG::Color.r(num).chr
				chars[1] = ChunkyPNG::Color.g(num).chr
				chars[2] = ChunkyPNG::Color.b(num).chr

				chars.each do|c|
					return text if c.ord.zero?
					text << c
				end
			end
		end
	end
	text
end

def hide_text(img, text)
	clean_image(img)

	interval = text.length - (text.length%3)
	left = text.length - interval

	idx = 0
	for i in 0...img.width
		for j in 0...img.height
			return idx if idx > text.length-1

			next if ChunkyPNG::Color.a(img[i,j]).nonzero?

			if idx == interval
				if left == 2
					img[i,j] = ChunkyPNG::Color.rgba(text[idx].ord, text[idx+1].ord, 0x00, 0x00)
				else
					img[i,j] = ChunkyPNG::Color.rgba(text[idx].ord, 0x00, 0x00, 0x00)
				end
				return idx + left
			end

			img[i,j] = ChunkyPNG::Color.rgba(text[idx].ord, text[idx+1].ord, text[idx+2].ord, 0x00)
			idx += 3
		end
	end
	idx
end

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT],
	['--clear-image', GetoptLong::NO_ARGUMENT],
	['--free-space', GetoptLong::NO_ARGUMENT],
	['--unhide', '-u', GetoptLong::NO_ARGUMENT],
	['--show-alpha', GetoptLong::NO_ARGUMENT],
	['--output-file', '-o', GetoptLong::REQUIRED_ARGUMENT],
	['--text', '-t', GetoptLong::REQUIRED_ARGUMENT],
	['--file', '-f', GetoptLong::REQUIRED_ARGUMENT],
	['--png-image', GetoptLong::REQUIRED_ARGUMENT])

var = {}

opts.quiet = true
begin
	opts.each do |op, arg|
		case op
		when '--help'
			$stdout.usage()
			exit
		when '--text'
			var[:text] = arg
		when '--file'
			var[:filename] = arg
		when '--png-image'
			var[:png_image] = arg
		when '--unhide'
			var[:unhide] = true
		when '--clear-image'
			var[:clear] = true
		when '--free-space'
			var[:space] = true
		when '--output-file'
			var[:output] = arg
		when '--show-alpha'
			var[:show_alpha] = true
		end
	end
rescue GetoptLong::MissingArgument
	$stderr.puts 'Option requires an argument.'
	exit
rescue GetoptLong::InvalidOption
	$stderr.puts 'Unknown option.'
	$stderr.usage
	exit
rescue
	puts $!
	exit
end

unless var[:png_image] 
	$stderr.puts '--> Please, provide an image to work with.'
	$stderr.usage
	exit
end

begin
	if not File.exists? var[:png_image] or var[:png_image] =~ /\.png$/i
		$stderr.puts "--> Image not found or it is not a *.png image `#{var[:png_image]}'"
		exit
	end
	img = ChunkyPNG::Image.from_file(var[:png_image])
rescue
	puts $!
	exit
end

if var[:space] and var[:clear]
	puts 'Cleaning image...'
	clean_image(img)
	puts 'Getting available space...'
	size = get_available_size(img)
	puts "\n#{size} bytes available."
	img.save(var[:png_image])
	exit

elsif var[:clear]
	print 'Cleaning the image...'
	clean_image(img)
	img.save(var[:png_image])
	puts 'Done.'
	exit

elsif var[:space]
	puts 'Getting available space...'
	size = get_available_size(img)
	puts "\n#{size} bytes available."
	exit

elsif var[:show_alpha]
	if var[:output]
		var[:output] += '.png' unless var[:output] =~ /\.png$/i

		print 'Changing bits...'
		show_alpha(img)

		puts "Done.\nSaving changes to `#{var[:output]}'..."
		img.save(var[:output])
		
	else
		$stderr.print '--> You must use the `--show-alpha\' function in conjunction with'
		$stderr.puts 'the `--output-file\' option.'
	end
	exit
elsif var[:unhide]
	payload = unhide_text(img)
	if var[:output] and payload!=''
		f = File.new(var[:output], 'w')
		f.write(payload)
		f.close
	else
		puts payload
	end

	puts "\n#{payload.size} bytes read."
	exit

elsif var[:filename] or var[:text]
	if var[:filename]
		begin
			var[:text] = IO.read(var[:filename])
		rescue
			puts "--> Problems reading the file `#{var[:filename]}'"
			puts "--> #$!"
			exit
		end
	end
	len = hide_text(img, var[:text]);

	print 'Saving changes...'
	img.save(var[:png_image])
	puts "\n#{len} bytes written."
else
	$stderr.puts '--> Please, provide an action.'
	$stderr.usage
	exit
end

__END__
Autor: MaG
Prove of concept program.

Uso: script [OPTIONS]

Optiones:
  --help, -h         Display this help and exit.
  --text, -t         Text to be hidden within the image.
  --file, -f         File to be hidden within the image. (text files only)
  --png-image        PNG image to work with.
  --unhide, -u       Gather the hidden information inside the image.
  --clear-image      Removes the information hidden within image.
  --free-space       Show available space and exit.
  --output-file, -o  Place output in a file.
  --show-alpha       Reveals the alpha channel of the image.


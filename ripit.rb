#!/usr/bin/ruby1.9

require 'rbrainz'
require 'mb-discid'
require 'fileutils'

include MusicBrainz

# Options
do_cdparanoia = true
do_flac = true
do_lame = true
lame_options = "--preset extreme"
ripit_home = "/home/shawn/Documents/ripit"

# Go to starting root
FileUtils.mkdir_p ripit_home
FileUtils.cd ripit_home

puts "Step 1 :: Caclulating the DiscID..."

disc_id = MusicBrainz::DiscID.new
disc_id.read

disc = MusicBrainz::Model::Disc.new
disc.id = disc_id

if ARGV[0] == "-d"
print <<EOF
DiscID      : #{disc_id.id}
Submit via  : #{disc_id.submission_url}
FreeDB ID   : #{disc_id.freedb_id}
First track : #{disc_id.first_track_num}
Last track  : #{disc_id.last_track_num}
Total length: #{disc_id.seconds} seconds
Sectors     : #{disc_id.sectors}
EOF
end

puts "Step 2 :: Lookup Album Release(s)..."

q = Webservice::Query.new
results = q.get_releases(Webservice::ReleaseFilter.new(:discid=>disc_id.id))

if results == nil or results.entities().length == 0
  puts "No matching release found for the DiscId '#{disc_id.id}'; use this link to upload the information:"
  puts "#{disc_id.submission_url}"
  exit(1)
elsif results.entities().length == 1
  release = results.entities()[0]

  puts "Found => #{release.artist.name}, #{release.title}"

  release.tracks.each_with_index { | track, i |
    if i < 9
      puts "0#{i+1}. #{track}"
    else
      puts "#{i+1}. #{track}"
    end
  } 
else
  puts "Found multiple ->"
  puts results.entities().length
  results.entities().each_with_index { | entity, i |
    puts entity
  }
  exit(1)
end

puts "Step 3 - Creating Folders"

FileUtils.mkdir_p "rips/#{release.artist.name}/#{release.title}"
FileUtils.mkdir_p "flac/#{release.artist.name}/#{release.title}"
FileUtils.mkdir_p "mp3/#{release.artist.name}/#{release.title}"

FileUtils.cd "rips/#{release.artist.name}/#{release.title}"

if do_cdparanoia == true
  puts "Step 4 - Running CD Paranoia"
  `cdparanoia -B`
end

puts "Setp 5 - Encoding"

release.tracks.each_with_index { | track, i |
  in_filename = i < 9 ? "track0#{i+1}.cdda.wav" : "track#{i+1}.cdda.wav"
  out_filename = i < 9 ? "0#{i+1}. #{track}" : "#{i+1}. #{track}"

  lame_id3_tags = "--tt \"#{track.title}\" --ta \"#{track.artist.name}\" --tl \"#{release.title}\" --tn #{i+1}/#{release.tracks.size} --tc \"#{track.id}.html\""

  if release.earliest_release_event == nil
    lame_id3_tags = lame_id3_tags + " --ty 9999"
  else
    lame_id3_tags = lame_id3_tags + " --ty \"#{release.earliest_release_event.date.year}\""
  end

  if do_flac == true
    `flac #{in_filename} -o "#{out_filename}.flac"`
      end

  if do_lame == true
    `lame #{lame_options} #{lame_id3_tags} #{in_filename} "#{out_filename}.mp3"`
  end
}

def copyEncodingToTypeDirectory ripit_home, release, file_type
  FileUtils.mv(Dir.glob("*.#{file_type}"), "#{ripit_home}/#{file_type}/#{release.artist.name}/#{release.title}")
end

copyEncodingToTypeDirectory(ripit_home, release, 'flac')
copyEncodingToTypeDirectory(ripit_home, release, 'mp3')

File.open("#{ripit_home}/mp3/#{release.artist.name}/Artist.URL", "w") { | f |
  f.puts("[InternetShortcut]")
  f.puts("URL=#{release.artist.id}.html")
}

File.open("#{ripit_home}/mp3/#{release.artist.name}/#{release.title}/Release.URL", "w") { | f |
  f.puts("[InternetShortcut]")
  f.puts("URL=#{release.id}.html")
}

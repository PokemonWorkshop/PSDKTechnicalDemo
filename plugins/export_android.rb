# Create the PSDK Source Archive
# Needs the gem 'rubyzip'

require 'zip'

def zip_all_recursive(zipfile, path)
    path = "#{path}/**"

    Dir.glob(path).each do |file_or_dir|
        if File.directory? (file_or_dir)
            zip_all_recursive(zipfile, file_or_dir)
        else
            puts "Adding #{file_or_dir}"
            zipfile.add(file_or_dir, file_or_dir)
        end
    end

end

ARCHIVE_NAME = "project.psa"
File.delete(ARCHIVE_NAME) if File.exist? ARCHIVE_NAME

Zip::File.open(ARCHIVE_NAME, create: true) do |zipfile|
    zip_all_recursive(zipfile, "{graphics,Fonts,Data,audio,pokemonsdk,scripts}")
    zipfile.add("Game.rb", "Game.rb")
end

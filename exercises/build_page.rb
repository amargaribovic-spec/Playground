# Builds meter-drills.html from page_template.html + exercises.json
require 'json'
dir = __dir__
data = JSON.parse(File.read(File.join(dir, 'exercises.json')))
json = JSON.generate(data).gsub('</', '<\/')
html = File.read(File.join(dir, 'page_template.html')).sub('__DATA__') { json }
File.write(File.join(dir, 'meter-drills.html'), html)
warn "meter-drills.html: #{html.bytesize / 1024} KB"

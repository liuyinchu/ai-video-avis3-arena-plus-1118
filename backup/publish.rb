# encoding: UTF-8
# frozen_string_literal: true
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

meta = File.expand_path(__dir__)
restored = File.expand_path(ARGV.fetch(0))
repo = ENV.fetch('GITHUB_REPOSITORY')
tag = ENV.fetch('GITHUB_REF_NAME')
raise 'Unexpected release target' unless repo=='liuyinchu/ai-video-avis3-arena-plus-1118' && tag=='backup-20261118'
archive = File.read(File.join(meta,'archive.sha256')).split.last
project = File.join(restored,'ai-video-1118-astra')
files = [File.join(restored,archive)] + Dir[File.join(project,'out','*')].select { |p| File.file?(p) } +
        Dir[File.join(project,'out','publish','*')].select { |p| File.file?(p) } +
        [File.join(meta,'project-files.json'),File.join(meta,'SHA256SUMS.txt')]
expected = File.readlines(File.join(meta,'SHA256SUMS.txt'),chomp:true).map { |row|
  digest,name=row.split(/  /,2); [name,digest]
}.to_h
expected['SHA256SUMS.txt']=Digest::SHA256.file(File.join(meta,'SHA256SUMS.txt')).hexdigest
by_name=files.map { |p| [File.basename(p),p] }.to_h
raise 'Unexpected or missing release files' unless files.size==by_name.size && by_name.keys.sort==expected.keys.sort
by_name.each { |name,p| raise "Local checksum failed for #{name}" unless Digest::SHA256.file(p).hexdigest==expected.fetch(name) }

def github(*args)
  out,err,status=Open3.capture3('gh',*args)
  raise "GitHub request failed: #{err}" unless status.success?
  out
end

def release(repo,tag)
  JSON.parse(github('api',"repos/#{repo}/releases?per_page=100")).find { |r| r.fetch('tag_name')==tag }
end

record=release(repo,tag)
unless record
  github('release','create',tag,'--repo',repo,'--verify-tag','--draft','--title','AVIS3 Arena Plus · 2026-11-18 完整工程备份','--notes-file',File.join(meta,'release-notes.md'))
  5.times do
    record=release(repo,tag)
    break if record
    sleep 2
  end
end
raise 'Cannot locate release' unless record
endpoint="repos/#{repo}/releases/#{record.fetch('id')}/assets?per_page=100"
assets=JSON.parse(github('api',endpoint)).map { |asset| [asset.fetch('name'),asset] }.to_h
by_name.each do |name,file|
  next if assets.key?(name)
  raise 'An existing published release is missing a required file' unless record.fetch('draft')
  github('release','upload',tag,file,'--repo',repo)
  puts "Uploaded #{name}"
end
assets=JSON.parse(github('api',endpoint)).map { |asset| [asset.fetch('name'),asset] }.to_h
by_name.each do |name,file|
  asset=assets.fetch(name)
  raise "Incomplete asset #{name}" unless asset.fetch('state')=='uploaded' && asset.fetch('size')==File.size(file)
  if asset['digest'].to_s.start_with?('sha256:')
    raise "GitHub digest mismatch for #{name}" unless asset['digest']=='sha256:'+expected.fetch(name)
  else
    Dir.mktmpdir('avis3-release-verify') do |tmp|
      path=File.join(tmp,name)
      ok=system('gh','api','-H','Accept: application/octet-stream',"repos/#{repo}/releases/assets/#{asset.fetch('id')}",out:path)
      raise "Download mismatch for #{name}" unless ok && Digest::SHA256.file(path).hexdigest==expected.fetch(name)
    end
  end
end
if record.fetch('draft')
  github('release','edit',tag,'--repo',repo,'--draft=false')
end
puts "Verified #{by_name.size} published assets for #{tag}"

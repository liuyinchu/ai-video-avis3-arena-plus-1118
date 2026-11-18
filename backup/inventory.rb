require 'json'
require 'digest'
require 'find'
root = File.expand_path(ARGV.fetch(0))
prefix = root + File::SEPARATOR
stat_time = ARGV[1] == '--with-mtime'
paths = []
Find.find(root) { |p| paths << (p == root ? '.' : p.delete_prefix(prefix)) }
entries = paths.sort_by(&:b).map do |relative|
  name = relative == '.' ? root : File.join(root, relative)
  st = File.lstat(name)
  mode = '%04o' % (st.mode & 07777)
  row = {'path' => relative, 'type' => st.ftype, 'mode' => mode}
  case st.ftype
  when 'file'
    row['bytes'] = st.size
    row['sha256'] = Digest::SHA256.file(name).hexdigest
  when 'link'
    row['target'] = File.readlink(name)
  when 'directory'
  else
    raise "Unexpected live filesystem object in snapshot: #{relative} (#{st.ftype})"
  end
  row['mtime_ns'] = st.mtime.to_i * 1_000_000_000 + st.mtime.nsec if stat_time
  row
end
puts JSON.pretty_generate({'schema'=>1,'project'=>File.basename(root),'entries'=>entries})

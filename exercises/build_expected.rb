# Runs every reference solution and writes exercises.json (exercise text + expected results).
#   ruby exercises/build_expected.rb            (from the repo folder; containers must be running)
# Local exercises run in your ClickHouse container, browser exercises on sql.clickhouse.com,
# dbt exercises in a throw-away copy of dbt/meter_project (your own project is not touched).
# The practice / lake / analytics databases are dropped at the end, so you start clean.
require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'
require_relative 'exercises'

ROOT = File.expand_path('..', __dir__)

def run!(cmd, stdin = nil)
  out, err, st = Open3.capture3(*cmd, stdin_data: stdin.to_s, chdir: ROOT)
  raise "Command failed: #{cmd.join(' ')}\n#{out}\n#{err}" unless st.success?
  out
end

def ch(sql)
  run!(%w[docker compose exec -T clickhouse clickhouse-client --multiquery
          --output_format_json_quote_64bit_integers=0 --output_format_json_quote_decimals=0], sql)
end

def playground(sql)
  run!(['curl', '-sS', '--fail-with-body', '--max-time', '120', '-u', 'demo:',
        'https://sql-clickhouse.clickhouse.com:8443/?output_format_json_quote_64bit_integers=0&output_format_json_quote_decimals=0',
        '--data-binary', '@-'], sql)
end

DBT_DIR = Dir.mktmpdir('meter_project_')
FileUtils.cp_r(File.join(ROOT, 'dbt/meter_project/.'), DBT_DIR)
%w[target logs].each { |d| FileUtils.rm_rf(File.join(DBT_DIR, d)) }

def dbt(cmd)
  run!(%W[docker compose run --rm -T -v #{DBT_DIR}:/usr/app/meter_project dbt] + cmd.split)
rescue RuntimeError => e
  raise "dbt #{cmd} failed:\n#{e.message.gsub(/\e\[[0-9;]*m/, '')[-3000..-1]}"
end

CLEAN = 'DROP DATABASE IF EXISTS practice; DROP DATABASE IF EXISTS lake; DROP DATABASE IF EXISTS analytics; DROP USER IF EXISTS dict_reader;'
ch(CLEAN)

begin
  out = EXERCISES.map do |e|
    e = e.dup
    e[:check] ||= 'auto'
    ch(e[:setup]) if e[:setup]
    if e[:dbt_files]
      e[:dbt_files].each do |path, body|
        file = File.join(DBT_DIR, path)
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, body)
      end
      e[:dbt_cmds].each { |c| dbt(c) }
    end
    if e[:check] == 'auto'
      q = (e[:verify] || e[:solution]).split(/;\s*(?:\n|\z)/).first.strip
      t0 = Time.now
      res = JSON.parse(e[:where] == 'browser' ? playground("#{q}\nFORMAT JSONCompact") : ch("#{q}\nFORMAT JSONCompact"))
      e[:expected] = {
        columns: res['meta'].map { |m| m['name'] },
        rows: res['data'].map { |r| r.map { |v| v.nil? ? nil : v.to_s } }
      }
      warn format('ex %2d %-34s %3d rows  %.1fs', e[:id], e[:title], e[:expected][:rows].size, Time.now - t0)
    else
      warn format('ex %2d %-34s review%s', e[:id], e[:title], e[:dbt_files] ? ' (dbt ran OK)' : '')
    end
    e[:solution] ||= "#{e[:setup].strip}\n\n-- check query\n#{e[:verify].strip}"
    e[:verify] = e[:verify] && e[:verify].strip
    %i[setup dbt_files dbt_cmds].each { |k| e.delete(k) }
    e
  end
  File.write(File.join(__dir__, 'exercises.json'), JSON.pretty_generate({ modules: MODULES, exercises: out }))
  warn "wrote #{out.size} exercises"
ensure
  ch(CLEAN)
  FileUtils.rm_rf(DBT_DIR)
end

# frozen_string_literal: true
# 清理脚本 - 用于手动清理现有的抽奖表

puts "开始清理现有的抽奖相关表..."

begin
  # 检查并删除表
  tables_to_drop = ['lottery_winners', 'lottery_participants', 'lotteries']
  
  tables_to_drop.each do |table_name|
    if ActiveRecord::Base.connection.table_exists?(table_name)
      puts "删除表: #{table_name}"
      ActiveRecord::Base.connection.drop_table(table_name, if_exists: true, cascade: true)
    else
      puts "表 #{table_name} 不存在，跳过"
    end
  end
  
  # 清理迁移记录
  migration_versions = [
    '20250101000001', # CreateLotteries
    '20250101000002', # CreateLotteryParticipants  
    '20250101000003', # CreateLotteryWinners
    '20250101000004'  # AddIndexes
  ]
  
  migration_versions.each do |version|
    if ActiveRecord::SchemaMigration.where(version: version).exists?
      puts "删除迁移记录: #{version}"
      ActiveRecord::SchemaMigration.where(version: version).delete_all
    end
  end
  
  puts "清理完成！现在可以重新运行迁移。"
  
rescue => e
  puts "清理过程中出现错误: #{e.message}"
  puts "请手动执行 SQL 清理命令。"
end

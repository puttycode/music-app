#!/bin/bash

echo "========================================="
echo "测试 GD Studio API 备用源"
echo "========================================="
echo ""

API_URL="http://localhost:37281"
API_KEY="your-secret-api-key"

# 测试 1: 搜索（应该使用 kw-api 主源）
echo "1. 测试搜索接口（主源 kw-api）"
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API_URL/api/v1/search?q=周杰伦&type=song&limit=3" | head -50
echo ""

# 测试 2: 播放链接
echo "2. 测试播放链接接口"
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API_URL/api/v1/url?id=228908&quality=exhigh"
echo ""

# 测试 3: 歌词
echo "3. 测试歌词接口"
curl -s -H "Authorization: Bearer $API_KEY" \
  "$API_URL/api/v1/lyric?id=228908" | head -20
echo ""

echo "========================================="
echo "测试完成！"
echo "========================================="

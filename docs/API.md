# Music API 接口文档

## 📋 接口概览

| 接口 | 路径 | 说明 | 认证 |
|------|------|------|------|
| 健康检查 | `GET /health` | 检查服务状态 | ❌ |
| 搜索 | `GET /api/v1/search` | 搜索歌曲/歌手/专辑 | ✅ |
| 详情 | `GET /api/v1/detail` | 获取歌手/专辑详情 | ✅ |
| 列表 | `GET /api/v1/list` | 获取列表 | ✅ |
| 播放链接 | `GET /api/v1/url` | 获取歌曲播放 URL | ✅ |
| 歌词 | `GET /api/v1/lyric` | 获取歌曲歌词 | ✅ |

**基础 URL**: `http://localhost:37281`

## 🔐 认证说明

```bash
Authorization: Bearer your-secret-api-key
```

## 📚 接口详情

### 1. GET /health
```bash
curl http://localhost:37281/health
```

### 2. GET /api/v1/search?q=周杰伦&type=song&page=1&limit=10
```bash
curl -H "Authorization: Bearer your-secret-api-key" \
  "http://localhost:37281/api/v1/search?q=周杰伦&type=song"
```

### 3. GET /api/v1/detail?id=336&type=artist
```bash
curl -H "Authorization: Bearer your-secret-api-key" \
  "http://localhost:37281/api/v1/detail?id=336&type=artist"
```

### 4. GET /api/v1/list?id=336&type=artistAlbums
```bash
curl -H "Authorization: Bearer your-secret-api-key" \
  "http://localhost:37281/api/v1/list?id=336&type=artistAlbums"
```

### 5. GET /api/v1/url?id=228908&quality=exhigh
```bash
curl -H "Authorization: Bearer your-secret-api-key" \
  "http://localhost:37281/api/v1/url?id=228908&quality=exhigh"
```

### 6. GET /api/v1/lyric?id=228908
```bash
curl -H "Authorization: Bearer your-secret-api-key" \
  "http://localhost:37281/api/v1/lyric?id=228908"
```

## 📊 数据源

**当前数据源**: 酷我音乐 (kw-api.cenguigui.cn)  
**曲库规模**: 5000 万 + 首歌曲

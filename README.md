# Netflix-Pro
# Netflix Pro - Streaming App

## GitHub Gist Server Configuration (`providers.json`)

App mein servers (Xtream IPTV aur Stremio Addons) ko load karne ke liye GitHub Gist mein `providers.json` file ka format bilkul niche diye gaye structure jaisa hona chahiye.

### Exact JSON Format (Copy & Paste)

```json
{
  "active_providers": [
    {
      "name": "Livebox Pro",
      "type": "xtream",
      "host": "[http://livebox.pro](http://livebox.pro)",
      "username": "YOUR_USERNAME",
      "password": "YOUR_PASSWORD"
    },
    {
      "name": "PenguPlay",
      "type": "stremio",
      "url": "[https://example.com/manifest.json](https://example.com/manifest.json)"
    }
  ]
}

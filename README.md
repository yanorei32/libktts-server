# libKTTS Server

<img width="800" height="243" alt="image" src="https://github.com/user-attachments/assets/d9e3c665-0187-44ce-9f49-5e14a2746114" />

## Introduction

> **조선어음성합성프로그람 《청봉》3.2** (kttsproject) is a program that reads text aloud.
>
> The kttsproject is our country's most excellent voice synthesis program, which won the honor of 1st place at the 17th National Program Contest and Exhibition in October Juche 95 (2006).

`libktts-server` is a server wrapper for this legacy TTS engine (kttsproject), allowing it to be used via a modern HTTP API.

## Official Hosted Instance

[https://libktts.yr32.net/](https://libktts.yr32.net/)

## Usage

### Docker

The easiest way to run `libktts-server` is using Docker, as it requires a specific 32-bit environment.

```bash
docker run -p 3000:3000 ghcr.io/yanorei32/libktts-server
```

### Configuration

You can configure the server using command-line arguments or environment variables.

| Argument | Env Var | Default | Description |
| :--- | :--- | :--- | :--- |
| `--listen` | `LISTEN` | `0.0.0.0:3000` | Socket address to bind to. |
| `--dic` | `DIC` | `/usr/share/apps/kttsdb/` | Path to the dictionary directory. |
| `--maximum-length` | `MAXIMUM_LENGTH` | `0` (Unlimited) | Maximum length of text to synthesize. |

### API

#### POST `/api/tts`

Synthesizes text to speech.

**Request:**

```json
{
  "text": "안녕하십니까?"
}
```

**Response:**

- **Content-Type**: `audio/wav`
- **Body**: WAV audio data.

If the text exceeds `MAXIMUM_LENGTH`, a `400 Bad Request` is returned.

## Technical Details

This project uses a multi-stage Docker build to run the 32-bit `libktts` binary on modern systems. The core library, `libkttsproject-4.0-1.i386.rpm`, was extracted from RedStar 3.0.
- **Base**: `debian:trixie-slim`
- **Runtime**: `debian:squeeze` (i386) environment extracted into the final image.
- **Server**: Rust (Axum) application acting as a bridge.

The server uses `memfd_create` to pass audio data from the legacy library to the HTTP response without writing to disk.

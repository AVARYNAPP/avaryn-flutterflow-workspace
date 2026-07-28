import { createClient } from 'npm:@supabase/supabase-js@2'
import decodeJpeg, {
  init as initJpegDecoder,
} from 'npm:@jsquash/jpeg@1.6.0/decode.js'
import decodeWebp, {
  init as initWebpDecoder,
} from 'npm:@jsquash/webp@1.5.0/decode.js'

const responseHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json',
}

const signedDownloadLifetimeSeconds = 60
const maxDecodedImageBytes = 32 * 1024 * 1024
let jpegDecoderReady: Promise<void> | null = null
let webpDecoderReady: Promise<void> | null = null

function ensureJpegDecoder() {
  jpegDecoderReady ??= initJpegDecoder({
    locateFile: () =>
      'https://cdn.jsdelivr.net/npm/@jsquash/jpeg@1.6.0/codec/dec/mozjpeg_dec.wasm',
  }).then(() => undefined)
  return jpegDecoderReady
}

function ensureWebpDecoder() {
  webpDecoderReady ??= initWebpDecoder({
    locateFile: () =>
      'https://cdn.jsdelivr.net/npm/@jsquash/webp@1.5.0/codec/dec/webp_dec.wasm',
  }).then(() => undefined)
  return webpDecoderReady
}
const allowedMimes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
])

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  })
}

function safeRpcError(message: string) {
  if (message.includes('AUTHENTICATION_REQUIRED')) return 'AUTHENTICATION_REQUIRED'
  if (message.includes('MEDIA_EDIT_REQUIRED')) return 'MEDIA_EDIT_REQUIRED'
  if (message.includes('MEDIA_VERSION_CONFLICT')) return 'MEDIA_VERSION_CONFLICT'
  if (message.includes('MEDIA_NOT_PENDING')) return 'MEDIA_NOT_PENDING'
  if (message.includes('MEDIA_NOT_READY')) return 'MEDIA_NOT_READY'
  if (message.includes('MEDIA_INPUT_INVALID')) return 'MEDIA_INPUT_INVALID'
  if (message.includes('MEDIA_FILENAME_INVALID')) return 'MEDIA_FILENAME_INVALID'
  if (message.includes('MEDIA_FINALIZE_INPUT_INVALID')) {
    return 'MEDIA_FINALIZE_INPUT_INVALID'
  }
  if (message.includes('MEDIA_ORIGINAL_INVALID')) return 'MEDIA_ORIGINAL_INVALID'
  if (message.includes('MEDIA_THUMBNAIL_INVALID')) {
    return 'MEDIA_THUMBNAIL_INVALID'
  }
  if (message.includes('REQUEST_ID_REUSED')) return 'REQUEST_ID_REUSED'
  return 'MEDIA_UNAVAILABLE'
}

function uint32be(bytes: Uint8Array, offset: number) {
  return (
    (
      bytes[offset] * 0x1000000 +
      (bytes[offset + 1] << 16) +
      (bytes[offset + 2] << 8) +
      bytes[offset + 3]
    ) >>> 0
  )
}

function crc32(bytes: Uint8Array) {
  let crc = 0xffffffff
  for (const byte of bytes) {
    crc ^= byte
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ ((crc & 1) === 1 ? 0xedb88320 : 0)
    }
  }
  return (crc ^ 0xffffffff) >>> 0
}

async function validPng(bytes: Uint8Array) {
  let offset = 8
  let width = 0
  let height = 0
  let bitDepth = 0
  let colorType = 0
  let seenHeader = false
  let seenData = false
  let seenEnd = false
  const compressedParts: Uint8Array[] = []
  while (offset < bytes.length) {
    if (seenEnd || offset + 12 > bytes.length) return false
    const length = uint32be(bytes, offset)
    const typeStart = offset + 4
    const dataStart = offset + 8
    const dataEnd = dataStart + length
    const chunkEnd = dataEnd + 4
    if (dataEnd < dataStart || chunkEnd > bytes.length) return false
    const type = String.fromCharCode(...bytes.slice(typeStart, dataStart))
    const expectedCrc = uint32be(bytes, dataEnd)
    if (crc32(bytes.slice(typeStart, dataEnd)) !== expectedCrc) return false
    if (!seenHeader && type !== 'IHDR') return false
    if (type === 'IHDR') {
      if (seenHeader || length !== 13) return false
      width = uint32be(bytes, dataStart)
      height = uint32be(bytes, dataStart + 4)
      bitDepth = bytes[dataStart + 8]
      colorType = bytes[dataStart + 9]
      const validDepths: Record<number, number[]> = {
        0: [1, 2, 4, 8, 16],
        2: [8, 16],
        3: [1, 2, 4, 8],
        4: [8, 16],
        6: [8, 16],
      }
      if (
        width === 0 ||
        height === 0 ||
        width > 20_000 ||
        height > 20_000 ||
        !validDepths[colorType]?.includes(bitDepth) ||
        bytes[dataStart + 10] !== 0 ||
        bytes[dataStart + 11] !== 0 ||
        bytes[dataStart + 12] !== 0
      ) return false
      seenHeader = true
    } else if (type === 'IDAT') {
      if (!seenHeader || seenEnd || length === 0) return false
      seenData = true
      compressedParts.push(bytes.slice(dataStart, dataEnd))
    } else if (type === 'IEND') {
      if (!seenHeader || !seenData || length !== 0) return false
      seenEnd = true
    }
    offset = chunkEnd
  }
  if (!seenEnd || offset !== bytes.length) return false
  const compressedSize = compressedParts.reduce(
    (total, part) => total + part.length,
    0,
  )
  const compressed = new Uint8Array(compressedSize)
  let writeOffset = 0
  for (const part of compressedParts) {
    compressed.set(part, writeOffset)
    writeOffset += part.length
  }
  const channels = ({ 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 } as Record<number, number>)[
    colorType
  ]
  const rowBytes = Math.ceil((width * channels * bitDepth) / 8)
  const expectedDecodedBytes = height * (rowBytes + 1)
  if (
    !Number.isSafeInteger(expectedDecodedBytes) ||
    expectedDecodedBytes > maxDecodedImageBytes
  ) return false
  try {
    const decompressedStream = new Blob([compressed]).stream().pipeThrough(
      new DecompressionStream('deflate'),
    )
    const reader = decompressedStream.getReader()
    let decodedBytes = 0
    while (true) {
      const { value, done } = await reader.read()
      if (done) break
      if (decodedBytes + value.length > expectedDecodedBytes) {
        await reader.cancel()
        return false
      }
      for (let index = 0; index < value.length; index += 1) {
        if (
          (decodedBytes + index) % (rowBytes + 1) === 0 &&
          value[index] > 4
        ) {
          await reader.cancel()
          return false
        }
      }
      decodedBytes += value.length
    }
    if (decodedBytes !== expectedDecodedBytes) return false
  } catch {
    return false
  }
  return true
}

function validJpeg(bytes: Uint8Array) {
  if (
    bytes.length < 16 ||
    bytes[0] !== 0xff ||
    bytes[1] !== 0xd8 ||
    bytes[bytes.length - 2] !== 0xff ||
    bytes[bytes.length - 1] !== 0xd9
  ) return false
  let offset = 2
  let seenFrame = false
  let seenScan = false
  let seenQuantization = false
  let seenHuffman = false
  const frameComponents = new Set<number>()
  while (offset < bytes.length) {
    if (bytes[offset] !== 0xff) return false
    while (offset < bytes.length && bytes[offset] === 0xff) offset += 1
    if (offset >= bytes.length) return false
    const marker = bytes[offset]
    offset += 1
    if (marker === 0xd9) return seenFrame && seenScan && offset === bytes.length
    if (marker === 0x00 || (marker >= 0xd0 && marker <= 0xd7)) return false
    if (offset + 2 > bytes.length) return false
    const segmentLength = (bytes[offset] << 8) | bytes[offset + 1]
    if (segmentLength < 2 || offset + segmentLength > bytes.length) return false
    const payloadStart = offset + 2
    const payloadEnd = offset + segmentLength
    if (marker === 0xdb) {
      let cursor = payloadStart
      while (cursor < payloadEnd) {
        const precision = bytes[cursor] >> 4
        const tableId = bytes[cursor] & 0x0f
        if (precision > 1 || tableId > 3) return false
        const valueBytes = precision === 0 ? 1 : 2
        const tableEnd = cursor + 1 + 64 * valueBytes
        if (tableEnd > payloadEnd) return false
        for (
          let coefficient = cursor + 1;
          coefficient < tableEnd;
          coefficient += valueBytes
        ) {
          const value = valueBytes === 1
            ? bytes[coefficient]
            : (bytes[coefficient] << 8) | bytes[coefficient + 1]
          if (value === 0) return false
        }
        cursor = tableEnd
      }
      if (cursor !== payloadEnd) return false
      seenQuantization = true
    }
    if (marker === 0xc4) {
      let cursor = payloadStart
      while (cursor < payloadEnd) {
        if (cursor + 17 > payloadEnd) return false
        const tableClass = bytes[cursor] >> 4
        const tableId = bytes[cursor] & 0x0f
        if (tableClass > 1 || tableId > 3) return false
        let symbolCount = 0
        for (let index = 1; index <= 16; index += 1) {
          symbolCount += bytes[cursor + index]
        }
        if (symbolCount === 0 || cursor + 17 + symbolCount > payloadEnd) {
          return false
        }
        cursor += 17 + symbolCount
      }
      if (cursor !== payloadEnd) return false
      seenHuffman = true
    }
    const frameMarker =
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf)
    if (frameMarker) {
      if (segmentLength < 11) return false
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4]
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6]
      const componentCount = bytes[offset + 7]
      if (
        width === 0 ||
        height === 0 ||
        componentCount < 1 ||
        componentCount > 4 ||
        segmentLength !== 8 + componentCount * 3 ||
        width * height * 4 > maxDecodedImageBytes
      ) return false
      frameComponents.clear()
      for (let component = 0; component < componentCount; component += 1) {
        const componentOffset = offset + 8 + component * 3
        const componentId = bytes[componentOffset]
        const sampling = bytes[componentOffset + 1]
        const quantizationTable = bytes[componentOffset + 2]
        if (
          frameComponents.has(componentId) ||
          (sampling >> 4) === 0 ||
          (sampling & 0x0f) === 0 ||
          quantizationTable > 3
        ) return false
        frameComponents.add(componentId)
      }
      seenFrame = true
    }
    if (marker === 0xda) {
      const scanComponentCount = bytes[offset + 2]
      if (
        !seenFrame ||
        !seenQuantization ||
        !seenHuffman ||
        scanComponentCount < 1 ||
        scanComponentCount > frameComponents.size ||
        segmentLength !== 6 + scanComponentCount * 2
      ) return false
      const seenScanComponents = new Set<number>()
      for (let component = 0; component < scanComponentCount; component += 1) {
        const componentId = bytes[offset + 3 + component * 2]
        const tableSelectors = bytes[offset + 4 + component * 2]
        if (
          !frameComponents.has(componentId) ||
          seenScanComponents.has(componentId) ||
          (tableSelectors >> 4) > 3 ||
          (tableSelectors & 0x0f) > 3
        ) return false
        seenScanComponents.add(componentId)
      }
    }
    offset += segmentLength
    if (marker === 0xda) {
      seenScan = true
      let entropyBytes = 0
      while (offset < bytes.length - 1) {
        if (bytes[offset] !== 0xff) {
          entropyBytes += 1
          offset += 1
          continue
        }
        const next = bytes[offset + 1]
        if (next === 0x00 || (next >= 0xd0 && next <= 0xd7)) {
          if (next === 0x00) entropyBytes += 1
          offset += 2
          continue
        }
        break
      }
      if (entropyBytes === 0) return false
    }
  }
  return false
}

function validWebp(bytes: Uint8Array) {
  if (
    bytes.length < 20 ||
    String.fromCharCode(...bytes.slice(0, 4)) !== 'RIFF' ||
    String.fromCharCode(...bytes.slice(8, 12)) !== 'WEBP'
  ) return false
  const riffSize =
    bytes[4] |
    (bytes[5] << 8) |
    (bytes[6] << 16) |
    (bytes[7] << 24)
  if ((riffSize >>> 0) !== bytes.length - 8) return false
  let offset = 12
  let frameChunks = 0
  let seenExtendedHeader = false
  while (offset < bytes.length) {
    if (offset + 8 > bytes.length) return false
    const type = String.fromCharCode(...bytes.slice(offset, offset + 4))
    const length =
      bytes[offset + 4] |
      (bytes[offset + 5] << 8) |
      (bytes[offset + 6] << 16) |
      (bytes[offset + 7] << 24)
    const unsignedLength = length >>> 0
    const dataStart = offset + 8
    const dataEnd = dataStart + unsignedLength
    const paddedEnd = dataEnd + (unsignedLength % 2)
    if (dataEnd < dataStart || paddedEnd > bytes.length) return false
    if (type === 'VP8X') {
      if (seenExtendedHeader || offset !== 12 || unsignedLength !== 10) return false
      if ((bytes[dataStart] & 0x02) !== 0) return false
      const width =
        1 +
        bytes[dataStart + 4] +
        (bytes[dataStart + 5] << 8) +
        (bytes[dataStart + 6] << 16)
      const height =
        1 +
        bytes[dataStart + 7] +
        (bytes[dataStart + 8] << 8) +
        (bytes[dataStart + 9] << 16)
      if (
        width <= 0 ||
        height <= 0 ||
        width * height * 4 > maxDecodedImageBytes
      ) return false
      seenExtendedHeader = true
    } else if (type === 'VP8 ' || type === 'VP8L') {
      frameChunks += 1
      if (unsignedLength < (type === 'VP8 ' ? 10 : 5)) return false
      if (type === 'VP8 ' && !(
        bytes[dataStart + 3] === 0x9d &&
        bytes[dataStart + 4] === 0x01 &&
        bytes[dataStart + 5] === 0x2a
      )) return false
      if (type === 'VP8L' && bytes[dataStart] !== 0x2f) return false
      if (type === 'VP8 ') {
        const firstPartitionLength =
          (
            bytes[dataStart] |
            (bytes[dataStart + 1] << 8) |
            (bytes[dataStart + 2] << 16)
          ) >>> 5
        const width =
          (bytes[dataStart + 6] | (bytes[dataStart + 7] << 8)) & 0x3fff
        const height =
          (bytes[dataStart + 8] | (bytes[dataStart + 9] << 8)) & 0x3fff
        if (
          firstPartitionLength === 0 ||
          firstPartitionLength > unsignedLength - 10 ||
          width === 0 ||
          height === 0 ||
          width * height * 4 > maxDecodedImageBytes
        ) return false
      } else {
        const bits =
          bytes[dataStart + 1] |
          (bytes[dataStart + 2] << 8) |
          (bytes[dataStart + 3] << 16) |
          (bytes[dataStart + 4] << 24)
        const width = (bits & 0x3fff) + 1
        const height = ((bits >>> 14) & 0x3fff) + 1
        const version = (bits >>> 29) & 0x07
        if (version !== 0 || width * height * 4 > maxDecodedImageBytes) {
          return false
        }
      }
    }
    offset = paddedEnd
  }
  return offset === bytes.length && frameChunks === 1
}

function validPdf(bytes: Uint8Array) {
  if (bytes.length < 32) return false
  const text = new TextDecoder('latin1').decode(bytes)
  if (!/^%PDF-[12]\.[0-9][\r\n]/.test(text)) return false
  const endMatch = text.match(/startxref\s+([0-9]+)\s+%%EOF\s*$/)
  if (!endMatch) return false
  const xrefOffset = Number(endMatch[1])
  if (!Number.isSafeInteger(xrefOffset) || xrefOffset < 9 || xrefOffset >= bytes.length) {
    return false
  }
  const startxrefIndex = text.lastIndexOf('startxref')
  const xrefTail = text.slice(xrefOffset, startxrefIndex)
  if (!xrefTail.startsWith('xref')) return false
  const trailerIndex = xrefTail.lastIndexOf('trailer')
  if (trailerIndex < 4) return false
  const trailerText = xrefTail.slice(trailerIndex)
  const trailerDictionary = trailerText.match(/^trailer\s*<<(.*?)>>\s*$/s)?.[1]
  if (!trailerDictionary) return false
  const rootMatch = trailerDictionary.match(/\/Root\s+([0-9]+)\s+([0-9]+)\s+R\b/)
  const sizeMatch = trailerDictionary.match(/\/Size\s+([0-9]+)\b/)
  if (!rootMatch || !sizeMatch) return false

  const lines = xrefTail
    .slice(4, trailerIndex)
    .trim()
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
  const inUse = new Map<number, { offset: number; generation: number }>()
  let lineIndex = 0
  while (lineIndex < lines.length) {
    const section = lines[lineIndex].match(/^([0-9]+)\s+([0-9]+)$/)
    if (!section) return false
    const firstObject = Number(section[1])
    const count = Number(section[2])
    if (
      !Number.isSafeInteger(firstObject) ||
      !Number.isSafeInteger(count) ||
      count < 1 ||
      count > 10_000 ||
      lineIndex + count >= lines.length
    ) return false
    lineIndex += 1
    for (let entryIndex = 0; entryIndex < count; entryIndex += 1) {
      const entry = lines[lineIndex]?.match(
        /^([0-9]{10})\s+([0-9]{5})\s+([nf])\s*$/,
      )
      if (!entry) return false
      if (entry[3] === 'n') {
        const objectNumber = firstObject + entryIndex
        const objectOffset = Number(entry[1])
        const generation = Number(entry[2])
        if (
          objectOffset < 9 ||
          objectOffset >= xrefOffset ||
          inUse.has(objectNumber)
        ) return false
        inUse.set(objectNumber, { offset: objectOffset, generation })
      }
      lineIndex += 1
    }
  }
  const declaredSize = Number(sizeMatch[1])
  if (
    !Number.isSafeInteger(declaredSize) ||
    declaredSize < 1 ||
    [...inUse.keys()].some((objectNumber) => objectNumber >= declaredSize)
  ) return false
  for (const [objectNumber, entry] of inUse) {
    const header = `${objectNumber} ${entry.generation} obj`
    if (!text.startsWith(header, entry.offset)) return false
  }
  const rootObject = Number(rootMatch[1])
  const rootGeneration = Number(rootMatch[2])
  const rootEntry = inUse.get(rootObject)
  if (!rootEntry || rootEntry.generation !== rootGeneration) return false
  const rootEnd = text.indexOf('endobj', rootEntry.offset)
  if (rootEnd < 0 || rootEnd >= xrefOffset) return false
  const rootBody = text.slice(rootEntry.offset, rootEnd)
  const pagesMatch = rootBody.match(/\/Pages\s+([0-9]+)\s+([0-9]+)\s+R\b/)
  if (!/\/Type\s*\/Catalog\b/.test(rootBody) || !pagesMatch) return false
  const pagesObject = Number(pagesMatch[1])
  const pagesGeneration = Number(pagesMatch[2])
  const pagesEntry = inUse.get(pagesObject)
  if (!pagesEntry || pagesEntry.generation !== pagesGeneration) return false
  const pagesEnd = text.indexOf('endobj', pagesEntry.offset)
  if (pagesEnd < 0 || pagesEnd >= xrefOffset) return false
  const pagesBody = text.slice(pagesEntry.offset, pagesEnd)
  return (
    /\/Type\s*\/Pages\b/.test(pagesBody) &&
    /\/Count\s+[0-9]+\b/.test(pagesBody) &&
    /\/Kids\s*\[/.test(pagesBody)
  )
}

async function decodedRasterIsValid(
  bytes: Uint8Array,
  decode: (data: ArrayBuffer) => Promise<ImageData>,
  decoderReady: Promise<void>,
) {
  try {
    await decoderReady
    const source = bytes.buffer.slice(
      bytes.byteOffset,
      bytes.byteOffset + bytes.byteLength,
    ) as ArrayBuffer
    const decoded = await decode(source)
    const decodedPixels = decoded.width * decoded.height
    return (
      Number.isSafeInteger(decoded.width) &&
      Number.isSafeInteger(decoded.height) &&
      decoded.width > 0 &&
      decoded.height > 0 &&
      decodedPixels * 4 <= maxDecodedImageBytes &&
      (
        decoded.data.byteLength === decodedPixels * 3 ||
        decoded.data.byteLength === decodedPixels * 4
      )
    )
  } catch {
    return false
  }
}

async function detectedMime(bytes: Uint8Array) {
  if (
    bytes.length >= 4 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff &&
    bytes[bytes.length - 2] === 0xff &&
    bytes[bytes.length - 1] === 0xd9
  ) {
    return validJpeg(bytes) &&
        await decodedRasterIsValid(bytes, decodeJpeg, ensureJpegDecoder())
      ? 'image/jpeg'
      : null
  }
  if (
    bytes.length >= 24 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a &&
    String.fromCharCode(...bytes.slice(12, 16)) === 'IHDR'
  ) return await validPng(bytes) ? 'image/png' : null
  if (
    bytes.length >= 16 &&
    String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF' &&
    String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP'
  ) {
    return validWebp(bytes) &&
        await decodedRasterIsValid(bytes, decodeWebp, ensureWebpDecoder())
      ? 'image/webp'
      : null
  }
  if (
    bytes.length >= 12 &&
    String.fromCharCode(...bytes.slice(0, 5)) === '%PDF-' &&
    new TextDecoder().decode(bytes.slice(-1024)).includes('%%EOF')
  ) return validPdf(bytes) ? 'application/pdf' : null
  return null
}

async function sha256Hex(bytes: Uint8Array) {
  const source = bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer
  const digest = await crypto.subtle.digest('SHA-256', source)
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: responseHeaders })
  }
  if (request.method !== 'POST') {
    return response(405, { code: 'METHOD_NOT_ALLOWED' })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const publishableKey =
    Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return response(503, { code: 'SERVER_CONFIGURATION_MISSING' })
  }

  let body: Record<string, unknown>
  try {
    body = await request.json()
  } catch {
    return response(400, { code: 'INVALID_REQUEST' })
  }
  const action = typeof body.action === 'string' ? body.action : ''
  const authorization = request.headers.get('Authorization') ?? ''
  const accessToken = authorization.startsWith('Bearer ')
    ? authorization.substring('Bearer '.length)
    : ''
  if (!accessToken) {
    return response(401, { code: 'AUTHENTICATION_REQUIRED' })
  }

  const callerClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser(accessToken)
  if (userError || !user) {
    return response(401, { code: 'INVALID_SESSION' })
  }

  if (action === 'create') {
    const mimeType = typeof body.mime_type === 'string' ? body.mime_type : ''
    if (!allowedMimes.has(mimeType)) {
      return response(400, { code: 'MEDIA_INPUT_INVALID' })
    }
    const { data, error } = await callerClient.rpc(
      'create_media_upload_session',
      {
        p_horse_id: body.horse_id,
        p_schedule_execution_id: body.schedule_execution_id ?? null,
        p_original_filename: body.original_filename,
        p_mime_type: mimeType,
        p_request_id: body.request_id,
      },
    )
    if (error || !data || typeof data !== 'object') {
      const code = safeRpcError(error?.message ?? '')
      return response(code.includes('REQUIRED') ? 403 : 409, { code })
    }
    const session = data as {
      media_asset_id: string
      row_version: number
      status: string
      bucket_id: string
      idempotent: boolean
      variants: Array<{
        variant: string
        object_path: string
        expected_mime_type: string
        max_byte_size: number
      }>
    }
    if (session.status === 'ready') {
      return response(200, {
        media_asset_id: session.media_asset_id,
        row_version: session.row_version,
        status: session.status,
        idempotent: true,
        uploads: [],
      })
    }
    if (session.status !== 'pending') {
      return response(409, { code: 'MEDIA_UPLOAD_SESSION_CLOSED' })
    }
    const uploads = []
    for (const variant of session.variants ?? []) {
      const { data: signed, error: signedError } = await serviceClient.storage
        .from(session.bucket_id)
        .createSignedUploadUrl(variant.object_path)
      if (signedError || !signed) {
        return response(503, { code: 'MEDIA_UPLOAD_SIGNING_UNAVAILABLE' })
      }
      uploads.push({
        variant: variant.variant,
        object_path: variant.object_path,
        expected_mime_type: variant.expected_mime_type,
        max_byte_size: variant.max_byte_size,
        signed_upload_url: signed.signedUrl,
        upload_token: signed.token,
      })
    }
    return response(200, {
      media_asset_id: session.media_asset_id,
      row_version: session.row_version,
      status: session.status,
      idempotent: session.idempotent,
      uploads,
    })
  }

  if (action === 'finalize') {
    const mediaAssetId =
      typeof body.media_asset_id === 'string' ? body.media_asset_id : ''
    const rowVersion =
      typeof body.expected_row_version === 'number'
        ? body.expected_row_version
        : null
    if (!mediaAssetId || rowVersion === null) {
      return response(400, { code: 'MEDIA_FINALIZE_INPUT_INVALID' })
    }
    const { data: session, error: sessionError } = await serviceClient.rpc(
      'get_media_upload_session',
      {
        p_actor_user_id: user.id,
        p_media_asset_id: mediaAssetId,
      },
    )
    if (sessionError || !session || typeof session !== 'object') {
      return response(409, {
        code: safeRpcError(sessionError?.message ?? ''),
      })
    }
    const uploadSession = session as {
      media_asset_id: string
      status: string
      bucket_id: string
      expected_mime_type: string
      variants: Array<{
        variant: string
        object_path: string
        expected_mime_type: string
        max_byte_size: number
      }>
    }
    if (uploadSession.media_asset_id !== mediaAssetId) {
      return response(409, { code: 'MEDIA_SESSION_MISMATCH' })
    }

    const verified: Record<
      string,
      { mime: string; size: number; sha256: string }
    > = {}
    for (const variant of uploadSession.variants ?? []) {
      const { data: stored, error: downloadError } = await serviceClient.storage
        .from(uploadSession.bucket_id)
        .download(variant.object_path)
      if (downloadError || !stored) {
        return response(409, { code: 'MEDIA_UPLOAD_INCOMPLETE' })
      }
      const bytes = new Uint8Array(await stored.arrayBuffer())
      if (bytes.length === 0 || bytes.length > variant.max_byte_size) {
        return response(409, { code: 'MEDIA_BYTE_SIZE_INVALID' })
      }
      const mime = await detectedMime(bytes)
      if (!mime || !allowedMimes.has(mime)) {
        return response(409, { code: 'MEDIA_CONTENT_TYPE_INVALID' })
      }
      verified[variant.variant] = {
        mime,
        size: bytes.length,
        sha256: await sha256Hex(bytes),
      }
    }
    const original = verified.original
    const thumbnail = verified.thumbnail
    if (
      !original ||
      original.mime !== uploadSession.expected_mime_type ||
      (
        original.mime !== 'application/pdf' &&
        (!thumbnail || thumbnail.mime !== original.mime)
      ) ||
      (original.mime === 'application/pdf' && thumbnail)
    ) {
      return response(409, { code: 'MEDIA_VARIANT_MISMATCH' })
    }
    const { data, error } = await serviceClient.rpc('finalize_media_asset', {
      p_actor_user_id: user.id,
      p_media_asset_id: mediaAssetId,
      p_expected_row_version: rowVersion,
      p_original_mime_type: original.mime,
      p_original_byte_size: original.size,
      p_original_sha256_hex: original.sha256,
      p_thumbnail_mime_type: thumbnail?.mime ?? null,
      p_thumbnail_byte_size: thumbnail?.size ?? null,
      p_thumbnail_sha256_hex: thumbnail?.sha256 ?? null,
      p_request_id: body.request_id,
    })
    if (error) {
      const code = safeRpcError(error.message)
      return response(code === 'MEDIA_VERSION_CONFLICT' ? 409 : 403, { code })
    }
    return response(200, data as Record<string, unknown>)
  }

  if (action === 'download') {
    const variant = body.variant === 'thumbnail' ? 'thumbnail' : 'original'
    const { data, error } = await serviceClient.rpc(
      'authorize_media_asset_download',
      {
        p_actor_user_id: user.id,
        p_media_asset_id: body.media_asset_id,
        p_variant: variant,
      },
    )
    const coordinate = Array.isArray(data) ? data[0] : null
    if (error || !coordinate) {
      return response(404, { code: 'MEDIA_UNAVAILABLE' })
    }
    const { data: signed, error: signedError } = await serviceClient.storage
      .from(coordinate.bucket_id)
      .createSignedUrl(coordinate.object_path, signedDownloadLifetimeSeconds)
    if (signedError || !signed) {
      return response(503, { code: 'MEDIA_DOWNLOAD_SIGNING_UNAVAILABLE' })
    }
    return response(200, {
      signed_download_url: signed.signedUrl,
      expires_in: signedDownloadLifetimeSeconds,
      mime_type: coordinate.mime_type,
    })
  }

  return response(400, { code: 'UNKNOWN_ACTION' })
})

const webStreams = require('stream/web');

if (typeof globalThis.TransformStream === 'undefined') {
  globalThis.TransformStream = webStreams.TransformStream;
}

if (typeof globalThis.ReadableStream === 'undefined') {
  globalThis.ReadableStream = webStreams.ReadableStream;
}

if (typeof globalThis.WritableStream === 'undefined') {
  globalThis.WritableStream = webStreams.WritableStream;
}

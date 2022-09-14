var memory = new WebAssembly.Memory({
    initial: 32,
    maximum: 512,
});

var importObject = {
    env: {
        consoleLog: (arg) => console.log(arg), // Useful for debugging on zig's side
        memory: memory,
    },
};

WebAssembly.instantiateStreaming(fetch("raytracer.wasm"), importObject).then((result) => {
    const wasmMemoryArray = new Uint8Array(memory.buffer);

  console.log(result);

    const canvas = document.getElementById("checkerboard");
    const context = canvas.getContext("2d");
    const imageData = context.createImageData(canvas.width, canvas.height);
    context.clearRect(0, 0, canvas.width, canvas.height);

    const drawCheckerboard = () => {

        result.instance.exports.tick();

        const bufferOffset = result.instance.exports.getCheckerboardBufferPointer();
        const imageDataArray = wasmMemoryArray.slice(
            bufferOffset,
            bufferOffset + (640 * 480 * 4)
        );

        imageData.data.set(imageDataArray);

        context.clearRect(0, 0, canvas.width, canvas.height);
        context.putImageData(imageData, 0, 0);
    };

    drawCheckerboard();
    setInterval(() => {
        drawCheckerboard();
    }, 1);
});

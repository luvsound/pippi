#cython: language_level=3

from pippi import dsp, oscs, fx, shapes
from PIL import Image, ImageOps, ImageStat

cpdef list _split(object img, int numpartials):
    cdef int width, height, partialheight

    width, height = img.size

    partialheight = <int>(height / numpartials)
    if partialheight < 1:
        partialheight = 1
        numpartials = img.size[1]

    if img.mode != 'RGB':
        img = img.convert('RGB')

    cdef tuple extremes = img.getextrema()

    cdef int upper = 0
    cdef int lower = partialheight
    cdef int left, right, bandindex, partialmin, partialmax
    cdef list bands, partial
    cdef list partials = []

    while lower <= height:
        left = 0
        right = 1

        partial = [ [] for _ in range(len(extremes)) ]
        while right <= width:
            channels = ImageStat.Stat(img.crop((left, upper, right, lower))).mean
            for i, c in enumerate(ImageStat.Stat(img.crop((left, upper, right, lower))).mean):
                partial[i] += [ 1 - (c / extremes[i][1]) ]

            left += 1
            right += 1

        partials += [[ dsp.wt(c) for c in partial ]]

        upper += partialheight
        lower += partialheight

    return partials

def partials(filename, numpartials=10):
    img = Image.open(filename)
    return _split(img, numpartials)

def sineosc(filename, freqs, length=10):
    img = Image.open(filename)
    wtpartials = _split(img, len(freqs))

    out = dsp.buffer(length=length)
    for freq, partial in zip(freqs, wtpartials):
        for env in partial:
            p = oscs.SineOsc(freq=freq, phase=dsp.rand()).play(length).env(dsp.win(env, 0, 1)).pan(dsp.rand())
            out.dub(p)
    out = fx.norm(out, 1)

    return out

def pulsar(filename, freqs, snd, length=10):
    img = Image.open(filename)
    wtpartials = _split(img, len(freqs))
    stack = dsp.ws(snd)

    out = dsp.buffer(length=snd.dur, channels=snd.channels, samplerate=snd.samplerate)
    for freq, partial in zip(freqs, wtpartials):
        for env in partial:
            p = oscs.Pulsar2d(stack, freq=freq, wt_mod=shapes.win('hann')).play(length)
            p = p.env(env).pan(dsp.rand())
            out.dub(p)
    out = fx.norm(out, 1)

    return out


def bandpass(filename, freqs, snd):
    img = Image.open(filename)
    wtpartials = _split(img, len(freqs))

    out = dsp.buffer(length=snd.dur, channels=snd.channels, samplerate=snd.samplerate)
    for freq, partial in zip(freqs, wtpartials):
        for env in partial:
            p = fx.buttbpf(snd, freq)
            p = fx.buttbpf(p, freq)
            p = fx.buttbpf(p, freq)
            p = fx.buttbpf(p, freq)
            p = fx.buttbpf(p, freq).env(env).pan(dsp.rand())
            out.dub(p)
    out = fx.norm(out, 1)

    return out



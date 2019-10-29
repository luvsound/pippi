TEST_RENDER_DIR ?= tests/renders

.PHONY: test test-fft test-soundfont test-grains test-wavesets test-fx test-noise test-shapes test-oscs test-soundbuffer test-lists build

$(TEST_RENDER_DIR):
	mkdir -p $(TEST_RENDER_DIR)

test: $(TEST_RENDER_DIR)
	python -m unittest discover -s tests -p 'test_*.py' -v

test-fft:
	python -m unittest tests/test_fft.py -v

test-soundfont:
	python -m unittest tests/test_soundfont.py -v

test-grains:
	python -m unittest tests/test_graincloud.py -v

test-wavesets:
	python -m unittest tests/test_wavesets.py -v

test-wavetables:
	python -m unittest tests/test_wavetables.py -v

test-fx:
	python -m unittest tests/test_fx.py -v

test-noise:
	python -m unittest tests/test_noise.py -v

test-shapes:
	python -m unittest tests/test_shapes.py -v

test-oscs:
	python -m unittest tests/test_oscs.py -v

test-soundbuffer:
	python -m unittest tests/test_soundbuffer.py -v

test-soundpipe:
	python -m unittest tests/test_soundpipe.py -v

test-lists:
	python -m unittest tests/test_lists.py -v

clean:
	rm -rf build/
	rm -rf pippi/*.c
	rm -rf pippi/*.so

install:
	pip install -r requirements.txt
	git submodule update --init
	cd modules/Soundpipe && make && sudo make install
	python setup.py develop

build:
	python setup.py develop

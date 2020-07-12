import glob
import os

def parse_cents(tuning):
    try:
        return 2**(float(tuning) / 1200)
    except (TypeError, ValueError):
        return None

def parse_ratio(tuning):
    if '/' in tuning:
        try:
            ratio = [ t for t in tuning.split('/') if t != '' ][:2]
            return int(ratio[0])/int(ratio[1])
        except (TypeError, ValueError):
            return None

    try:
        return int(tuning)
    except (TypeError, ValueError):
        return None

def import_file(filename):
    if '.scl' not in filename:
        raise ValueError('This doesn\'t look like a Scala file')

    with open(filename, encoding='latin-1') as tuning_file:
        description = None
        scale_length = None
        tunings = []
        for line in tuning_file:
            if line[0] == '!':
                continue

            if description is None:
                description = line.strip()
                continue
            elif scale_length is None:
                try:
                    scale_length = int(line.strip())
                    continue
                except (TypeError, ValueError) as e:
                    raise ValueError('Invalid value for scale length') from e

            tuning = line.strip().split(' ')[0]

            if '.' in tuning:
                tuning = parse_cents(tuning)
            else:
                tuning = parse_ratio(tuning)

            if tuning is None:
                continue

            tunings += [ tuning ]

    return {
        'filename': filename, 
        'description': description, 
        'scale': [1] + tunings[:scale_length], 
    }


def import_directory(directory):
    scales = []
    for filename in glob.glob(os.path.join(directory, '*.scl')):
        try:
            scale = import_file(filename)
            scales += [ scale ]
        except Exception as e:
            print(e)
            continue

    return scales

if __name__ == '__main__':
    scales = import_directory('./scl/')
    print(len(scales))

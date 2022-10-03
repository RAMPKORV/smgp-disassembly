import re


class SMGP:

    def __init__(self, path):
        self.byte_pattern = re.compile('\\$[0-9A-F]{2,8}')
        with open(path) as f:
            self.lines = f.readlines()

    def extract_loc_data(self, loc, extract_bytes=True):
        loc_found = False
        result = []

        for line in self.lines:
            if line.startswith(loc):
                loc_found = True
            elif loc_found:
                if line.startswith('loc') or line.startswith(';loc'):  # end of target_loc
                    break
                if extract_bytes:
                    result += self.byte_pattern.findall(line)
                else:
                    result += [line]
        return result

    def extract_track_data(self):
        track_data_offset = next(i for i, line in enumerate(self.lines) if line.startswith('Track_data')) + 1
        tracks = dict()

        NUM_TRACKS = 16
        for i in range(NUM_TRACKS):
            track = self.lines[track_data_offset + i * 20:track_data_offset + i * 20 + 19]
            name = track[0][2:].strip()
            tracks[name] = [t.strip() for t in track[1:]]

        return tracks


def extract_track_data_part(data_name, track):
    for line in track:
        if data_name in line:
            if '\t' in line:
                line = line[line.index('\t') + 1:]
            if ';' in line:
                line = line[:line.index(';')]
            return line.strip()
    return None


def parse_signed_byte(s):
    x = int(s[1:], 16)
    if x > 2 ** 7 - 1:
        x = x - 2 ** 8
    return x


# Call as f('$FF', '$FF') or f('$FFFF')
def parse_signed_word(high, low=None):
    if low:
        x = int(high[1:] + low[1:], 16)
    else:
        x = int(high[1:], 16)
    if x > 2 ** 15 - 1:
        x = x - 2 ** 16
    return x


def parse_curveslope_byte(s):
    b = int(s[1:], 16)
    if b == 0:
        return 0
    slope = (b & 0x3F) - 0x30
    if b & 0x40:
        slope = -slope
    return slope


def parse_slope_data(slope):
    slope = slope.copy()
    slope.reverse()  # Reverse so pop() gets from start
    slope.pop()  # ignore initial background displacement

    rles = []  # run length encoding tuples

    while slope:
        b1 = slope.pop()
        if b1 == '$FF':
            break
        b2 = slope.pop()
        b3 = slope.pop()
        if b3 != '$00':
            slope.pop()  # ignore background displacement
        length = parse_signed_word(b1, b2)
        value = parse_curveslope_byte(b3)
        rles += [(length, value)]

    return rles


def parse_curve_data(curve):
    curve = curve.copy()
    curve.reverse()  # Reverse so pop() gets from start

    rles = []  # run length encoding tuples

    while curve:
        b1 = curve.pop()
        if b1 == '$FF':
            break
        b2 = curve.pop()
        b3 = curve.pop()
        background_displacement = parse_signed_word(curve.pop(), curve.pop()) if b3 != '$00' else 0
        length = parse_signed_word(b1, b2)
        value = parse_curveslope_byte(b3)
        rles += [(length, value, background_displacement)]

    return rles


def rle_decode(rles):
    for rle in rles:
        for n in range(rle[0]):
            yield rle[1]

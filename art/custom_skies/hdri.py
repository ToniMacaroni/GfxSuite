import cv2
from PIL import Image
import numpy as np
import glob
from os import path, remove, getenv
from pathlib import Path
import sys

def generate_mapping_data(image_width):
    out_tex_width = image_width
    out_tex_height = image_width * 3 // 4
    face_edge_size = out_tex_width / 4

    out_mapping = np.zeros((out_tex_height, out_tex_width, 2), dtype="f4")
    xyz = np.zeros((out_tex_height * out_tex_width // 2, 3), dtype="f4")
    vals = np.zeros((out_tex_height * out_tex_width // 2, 3), dtype="i4")

    start, end = 0, 0
    pix_column_range_1 = np.arange(0, face_edge_size * 3)
    pix_column_range_2 = np.arange(face_edge_size, face_edge_size * 2)
    for col_idx in range(out_tex_width):

        face = int(col_idx / face_edge_size)
        col_pix_range = pix_column_range_1 if face == 1 else pix_column_range_2

        end += len(col_pix_range)
        vals[start:end, 0] = col_pix_range
        vals[start:end, 1] = col_idx
        vals[start:end, 2] = face
        start = end

    col_pix_range, col_idx, face = vals.T
    face[col_pix_range < face_edge_size] = 4  # top
    face[col_pix_range >= 2 * face_edge_size] = 5  # bottom

    a = 2.0 * col_idx / face_edge_size
    b = 2.0 * col_pix_range / face_edge_size
    one_arr = np.ones(len(a))
    for k in range(6):
        face_idx = face == k

        one_arr_idx = one_arr[face_idx]
        a_idx = a[face_idx]
        b_idx = b[face_idx]

        if k == 0: # X-positive face mapping
           vals_to_use = [one_arr_idx, a_idx - 1.0, 3.0 - b_idx]
        elif k == 1: # Y-positive face mapping
           vals_to_use = [3.0-a_idx, one_arr_idx, 3.0 - b_idx]
        elif k == 2: # X-negative face mapping
           vals_to_use = [-one_arr_idx, 5.0 - a_idx, 3.0 - b_idx]
        elif k == 3: # Y-negative face mapping
           vals_to_use = [a_idx - 7.0, -one_arr_idx, 3.0 - b_idx]
        elif k == 4: # Z-positive face mapping
           vals_to_use = [3.0 - a_idx, b_idx - 1.0, one_arr_idx]
        elif k == 5: # bottom face mapping
           vals_to_use = [3.0 - a_idx, 5.0 - b_idx, -one_arr_idx]

        xyz[face_idx] = np.array(vals_to_use).T

    x, y, z = xyz.T
    phi = np.arctan2(y, x)
    r_proj_xy = np.sqrt(x**2 + y**2)
    theta = np.pi / 2 - np.arctan2(z, r_proj_xy)

    uf = 4.0 * face_edge_size * phi / (2.0 * np.pi) % out_tex_width
    vf = 2.0 * face_edge_size * theta / np.pi
    
    out_mapping[col_pix_range, col_idx, 0] = uf
    out_mapping[col_pix_range, col_idx, 1] = vf
    
    return out_mapping[:, :, 0], out_mapping[:, :, 1]


def extract_cubemap_faces_from_cross(cubemap_texture, face_size):
    cubemap_faces = {}

    face_positions = {
        'pz':    (face_size, 0, None),
        'px':   (face_size, face_size, cv2.ROTATE_90_COUNTERCLOCKWISE),
        'nz':  (face_size, face_size*2, cv2.ROTATE_180),
        'nx':  (face_size, face_size*3, cv2.ROTATE_90_CLOCKWISE),
        'py': (0, face_size, cv2.ROTATE_90_COUNTERCLOCKWISE),
        'ny':   (face_size*2, face_size, None),
    }

    for face, (y_start, x_start, rot) in face_positions.items():
        x_end = x_start + face_size
        y_end = y_start + face_size

        face_image = cubemap_texture[y_start:y_end, x_start:x_end]
        if rot is not None: face_image = cv2.rotate(face_image, rot)
        cubemap_faces[face] = face_image

    return cubemap_faces

dir = path.dirname(path.realpath(__file__))
# dir = Path(path.join(getenv('LOCALAPPDATA'), "BeamNG.drive\\0.32\\mods\\unpacked\\foliage_sss\\art\\skies")).resolve().as_posix()

def adjust_exposure(image, exposure):
    return np.clip(image * exposure, 0, 255).astype(np.uint8)

def gamma_correction(image, gamma):
    invGamma = 1.0 / gamma
    table = np.array([((i / 255.0) ** invGamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
    return cv2.LUT(image, table)

if len(sys.argv) < 2:
    print("No image specified")
    exit()

if not sys.argv[1].endswith(".hdr"):
    ldr_image_rgb = cv2.imread(sys.argv[1], cv2.IMREAD_UNCHANGED)
    ldr_image_rgb = cv2.cvtColor(ldr_image_rgb, cv2.COLOR_BGR2RGB)
else:
    # tonemap = cv2.createTonemapDrago(gamma=2, saturation=1)
    # tonemap = cv2.xphoto.createTonemapDurand(2.2)
    # tonemap = cv2.createTonemapReinhard(gamma=1, intensity=1, light_adapt=1, color_adapt=0)
    tonemap = cv2.createTonemapMantiuk(gamma=1, scale=1, saturation=0.6)

    hdr_image = cv2.imread(sys.argv[1], cv2.IMREAD_UNCHANGED)
    ldr_image = tonemap.process(hdr_image)
    #ldr_image = adjust_exposure(hdr_image, 1)
    #ldr_image = gamma_correction(ldr_image, 1.68)

    ldr_image = cv2.normalize(ldr_image, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX)
    ldr_image_8bit = np.uint8(ldr_image)
    # ldr_image_8bit = adjust_exposure(ldr_image_8bit, 1.5)
    ldr_image_rgb = cv2.cvtColor(ldr_image_8bit, cv2.COLOR_BGR2RGB)
    # Image.fromarray(ldr_image_rgb).save(f'{dir}\\ldr_image.png')
    # exit()

filename = path.basename(sys.argv[1]).split(".")[0]

map_x_32, map_y_32 = generate_mapping_data(ldr_image_rgb.shape[1])
cubemap = cv2.remap(ldr_image_rgb, map_x_32, map_y_32, cv2.INTER_LINEAR)

height, width, _ = cubemap.shape
face_size = width // 4

cubemap_faces = extract_cubemap_faces_from_cross(cubemap, face_size)

Path(f'{dir}\\{filename}').mkdir(parents=True, exist_ok=True)

# imgOut = Image.fromarray(cubemap)
# imgOut.save(f'{dir}\\{filename}_cubemap.png')

for face_name, face_image in cubemap_faces.items():
    Image.fromarray(face_image).save(f'{dir}\\{filename}\\{face_name}.png')

#remove(hdr_files[0])
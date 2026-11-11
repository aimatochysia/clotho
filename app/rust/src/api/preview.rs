//! File contents for previews of changes Git calls binary (images, Aseprite
//! sprites, ...). The app decides how to show them from the file extension.

use std::io::Read;
use std::path::Path;

use git2::{Oid, Repository, Tree};

use crate::error::{CoreError, CoreResult};
use crate::util::{self, open_repo};

/// Files larger than this are described by size only.
const MAX_PREVIEW_BYTES: u64 = 25 * 1024 * 1024;

/// One side of a change. `data` is None when the file does not exist on that
/// side (added or deleted) or is too large to preview.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileSide {
    pub exists: bool,
    pub size: u64,
    pub data: Option<Vec<u8>>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileVersions {
    pub before: FileSide,
    pub after: FileSide,
}

fn missing() -> FileSide {
    FileSide {
        exists: false,
        size: 0,
        data: None,
    }
}

fn side(bytes: &[u8]) -> FileSide {
    let size = bytes.len() as u64;
    FileSide {
        exists: true,
        size,
        data: (size <= MAX_PREVIEW_BYTES).then(|| bytes.to_vec()),
    }
}

fn blob_side(repo: &Repository, oid: Oid) -> CoreResult<FileSide> {
    let blob = repo.find_blob(oid)?;
    Ok(side(blob.content()))
}

fn tree_side(repo: &Repository, tree: Option<&Tree>, file: &str) -> CoreResult<FileSide> {
    let Some(tree) = tree else {
        return Ok(missing());
    };
    match tree.get_path(Path::new(file)) {
        Ok(entry) if entry.kind() == Some(git2::ObjectType::Blob) => blob_side(repo, entry.id()),
        Ok(_) => Ok(missing()),
        Err(e) if e.code() == git2::ErrorCode::NotFound => Ok(missing()),
        Err(e) => Err(e.into()),
    }
}

fn index_side(repo: &Repository, file: &str) -> CoreResult<Option<FileSide>> {
    let index = repo.index()?;
    match index.get_path(Path::new(file), 0) {
        Some(entry) => Ok(Some(blob_side(repo, entry.id)?)),
        None => Ok(None),
    }
}

/// Both sides of a working change: HEAD → index when `staged`, otherwise
/// index → working tree (like the text diff).
pub fn working_file_versions(path: String, file: String, staged: bool) -> CoreResult<FileVersions> {
    let repo = open_repo(&path)?;
    let workdir = util::workdir(&repo)?.to_path_buf();
    let head = match repo.head() {
        Ok(h) => Some(h.peel_to_tree()?),
        Err(e) if e.code() == git2::ErrorCode::UnbornBranch => None,
        Err(e) => return Err(e.into()),
    };
    if staged {
        let old = tree_side(&repo, head.as_ref(), &file)?;
        let new = index_side(&repo, &file)?.unwrap_or_else(missing);
        return Ok(FileVersions {
            before: old,
            after: new,
        });
    }
    let old = index_side(&repo, &file)?.unwrap_or_else(missing);
    let on_disk = workdir.join(&file);
    let new = match std::fs::metadata(&on_disk) {
        Ok(m) if m.is_file() => {
            if m.len() > MAX_PREVIEW_BYTES {
                FileSide {
                    exists: true,
                    size: m.len(),
                    data: None,
                }
            } else {
                side(&std::fs::read(&on_disk)?)
            }
        }
        _ => missing(),
    };
    Ok(FileVersions {
        before: old,
        after: new,
    })
}

/// Both sides of `file` in commit `oid`, compared with its first parent.
pub fn commit_file_versions(
    path: String,
    oid: String,
    file: String,
    old_path: Option<String>,
) -> CoreResult<FileVersions> {
    let repo = open_repo(&path)?;
    let oid = Oid::from_str(&oid).map_err(|_| CoreError::InvalidInput {
        message: format!("{oid} is not a commit id"),
    })?;
    let commit = repo.find_commit(oid)?;
    let tree = commit.tree()?;
    let parent_tree = match commit.parent(0) {
        Ok(p) => Some(p.tree()?),
        Err(_) => None,
    };
    let old_name = old_path.unwrap_or_else(|| file.clone());
    Ok(FileVersions {
        before: tree_side(&repo, parent_tree.as_ref(), &old_name)?,
        after: tree_side(&repo, Some(&tree), &file)?,
    })
}

// ---- Aseprite ---------------------------------------------------------------

fn bad(why: &str) -> CoreError {
    CoreError::InvalidInput {
        message: format!("cannot preview this Aseprite file: {why}"),
    }
}

struct Reader<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    fn new(data: &'a [u8]) -> Self {
        Reader { data, pos: 0 }
    }
    fn take(&mut self, n: usize) -> CoreResult<&'a [u8]> {
        let end = self.pos.checked_add(n).ok_or_else(|| bad("truncated"))?;
        let s = self
            .data
            .get(self.pos..end)
            .ok_or_else(|| bad("truncated"))?;
        self.pos = end;
        Ok(s)
    }
    fn u8(&mut self) -> CoreResult<u8> {
        Ok(self.take(1)?[0])
    }
    fn u16(&mut self) -> CoreResult<u16> {
        let b = self.take(2)?;
        Ok(u16::from_le_bytes([b[0], b[1]]))
    }
    fn i16(&mut self) -> CoreResult<i16> {
        Ok(self.u16()? as i16)
    }
    fn u32(&mut self) -> CoreResult<u32> {
        let b = self.take(4)?;
        Ok(u32::from_le_bytes([b[0], b[1], b[2], b[3]]))
    }
    fn string(&mut self) -> CoreResult<()> {
        let n = self.u16()? as usize;
        self.take(n)?;
        Ok(())
    }
}

struct Cel {
    layer: usize,
    x: i32,
    y: i32,
    opacity: u8,
    w: usize,
    h: usize,
    pixels: Vec<u8>,
}

struct Layer {
    visible: bool,
    opacity: u8,
    is_image: bool,
}

/// Renders the first frame of an Aseprite (.ase/.aseprite) file to PNG,
/// blending visible layers normally. Good enough for a before/after preview.
pub fn render_aseprite(data: Vec<u8>) -> CoreResult<Vec<u8>> {
    let mut r = Reader::new(&data);
    r.u32()?; // file size
    if r.u16()? != 0xA5E0 {
        return Err(bad("not an Aseprite file"));
    }
    let frames = r.u16()?;
    let width = r.u16()? as usize;
    let height = r.u16()? as usize;
    let depth = r.u16()?;
    let flags = r.u32()?;
    r.take(2 + 4 + 4)?; // speed, reserved
    let transparent_index = r.u8()?;
    r.take(128 - r.pos)?;
    if frames == 0 || width == 0 || height == 0 {
        return Err(bad("empty sprite"));
    }
    if width * height > 16_777_216 {
        return Err(bad("sprite too large"));
    }
    if !matches!(depth, 8 | 16 | 32) {
        return Err(bad("unknown colour depth"));
    }
    let layer_opacity_valid = flags & 1 != 0;

    // First frame header.
    let frame_start = r.pos;
    let frame_len = r.u32()? as usize;
    if r.u16()? != 0xF1FA {
        return Err(bad("damaged frame"));
    }
    let old_chunks = r.u16()? as u32;
    r.take(2 + 2)?; // duration, reserved
    let new_chunks = r.u32()?;
    let chunks = if new_chunks == 0 {
        old_chunks
    } else {
        new_chunks
    };
    let frame_end = frame_start.saturating_add(frame_len).min(data.len());

    let mut palette = vec![[0u8, 0, 0, 255]; 256];
    let mut layers: Vec<Layer> = vec![];
    // Visibility of the group at each nesting level.
    let mut group_visible: Vec<bool> = vec![];
    let mut cels: Vec<Cel> = vec![];

    for _ in 0..chunks {
        if r.pos + 6 > frame_end {
            break;
        }
        let start = r.pos;
        let size = r.u32()? as usize;
        let kind = r.u16()?;
        let end = start.saturating_add(size).min(frame_end);
        if size < 6 {
            break;
        }
        let mut c = Reader::new(&data[r.pos..end]);
        match kind {
            0x2004 => {
                let lflags = c.u16()?;
                let ltype = c.u16()?;
                let level = c.u16()? as usize;
                c.take(2 + 2 + 2)?; // default size, blend mode
                let opacity = c.u8()?;
                group_visible.truncate(level);
                let parents_visible = group_visible.iter().all(|v| *v);
                let visible = lflags & 1 != 0 && parents_visible;
                if ltype == 1 {
                    group_visible.push(visible);
                }
                layers.push(Layer {
                    visible,
                    opacity: if layer_opacity_valid { opacity } else { 255 },
                    is_image: ltype == 0,
                });
            }
            0x2005 => {
                let layer = c.u16()? as usize;
                let x = c.i16()? as i32;
                let y = c.i16()? as i32;
                let opacity = c.u8()?;
                let ctype = c.u16()?;
                c.take(2 + 5)?; // z-index, reserved
                if ctype == 0 || ctype == 2 {
                    let w = c.u16()? as usize;
                    let h = c.u16()? as usize;
                    let rest = &c.data[c.pos..];
                    let pixels = if ctype == 0 {
                        rest.to_vec()
                    } else {
                        let mut out = Vec::with_capacity(w * h * (depth as usize / 8));
                        flate2::read::ZlibDecoder::new(rest)
                            .take(64 * 1024 * 1024)
                            .read_to_end(&mut out)
                            .map_err(|_| bad("damaged image data"))?;
                        out
                    };
                    cels.push(Cel {
                        layer,
                        x,
                        y,
                        opacity,
                        w,
                        h,
                        pixels,
                    });
                }
            }
            0x2019 => {
                c.u32()?; // new size
                let first = c.u32()? as usize;
                let last = c.u32()? as usize;
                c.take(8)?;
                for entry in palette.iter_mut().take(last.min(255) + 1).skip(first) {
                    let eflags = c.u16()?;
                    let rgba = [c.u8()?, c.u8()?, c.u8()?, c.u8()?];
                    if eflags & 1 != 0 {
                        c.string()?;
                    }
                    *entry = rgba;
                }
            }
            0x0004 | 0x0011 => {
                let packets = c.u16()?;
                let mut idx = 0usize;
                for _ in 0..packets {
                    idx += c.u8()? as usize;
                    let n = match c.u8()? {
                        0 => 256,
                        n => n as usize,
                    };
                    for _ in 0..n {
                        let (r8, g8, b8) = (c.u8()?, c.u8()?, c.u8()?);
                        let scale = |v: u8| {
                            if kind == 0x0011 {
                                v.saturating_mul(4)
                            } else {
                                v
                            }
                        };
                        if idx < 256 {
                            palette[idx] = [scale(r8), scale(g8), scale(b8), 255];
                        }
                        idx += 1;
                    }
                }
            }
            _ => {}
        }
        r.pos = end;
    }

    let mut canvas = vec![0u8; width * height * 4];
    let bpp = depth as usize / 8;
    // Cels are listed in layer order within the frame; draw bottom to top.
    cels.sort_by_key(|c| c.layer);
    for Cel {
        layer,
        x,
        y,
        opacity,
        w,
        h,
        pixels,
    } in cels
    {
        let Some(l) = layers.get(layer) else { continue };
        if !l.visible || !l.is_image {
            continue;
        }
        let alpha_mul = opacity as u32 * l.opacity as u32 / 255;
        for row in 0..h {
            let cy = y + row as i32;
            if cy < 0 || cy >= height as i32 {
                continue;
            }
            for col in 0..w {
                let cx = x + col as i32;
                if cx < 0 || cx >= width as i32 {
                    continue;
                }
                let i = (row * w + col) * bpp;
                let Some(px) = pixels.get(i..i + bpp) else {
                    continue;
                };
                let src = match depth {
                    32 => [px[0], px[1], px[2], px[3]],
                    16 => [px[0], px[0], px[0], px[1]],
                    _ => {
                        if px[0] == transparent_index {
                            continue;
                        }
                        palette[px[0] as usize]
                    }
                };
                let sa = src[3] as u32 * alpha_mul / 255;
                if sa == 0 {
                    continue;
                }
                let o = ((cy as usize) * width + cx as usize) * 4;
                let dst = &mut canvas[o..o + 4];
                let da = dst[3] as u32;
                let out_a = sa + da * (255 - sa) / 255;
                for k in 0..3 {
                    let s = src[k] as u32 * sa;
                    let d = dst[k] as u32 * da * (255 - sa) / 255;
                    dst[k] = ((s + d) / out_a.max(1)) as u8;
                }
                dst[3] = out_a as u8;
            }
        }
    }

    let mut png_bytes = vec![];
    {
        let mut enc = png::Encoder::new(&mut png_bytes, width as u32, height as u32);
        enc.set_color(png::ColorType::Rgba);
        enc.set_depth(png::BitDepth::Eight);
        let mut w = enc.write_header().map_err(|_| bad("could not encode"))?;
        w.write_image_data(&canvas)
            .map_err(|_| bad("could not encode"))?;
    }
    Ok(png_bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::TestRepo;
    use std::io::Write as _;

    /// A 2x1 RGBA sprite: one visible layer with a compressed cel holding a
    /// red and a half-transparent green pixel, plus a hidden layer on top.
    fn sprite() -> Vec<u8> {
        let mut zl = flate2::write::ZlibEncoder::new(vec![], flate2::Compression::default());
        zl.write_all(&[255, 0, 0, 255, 0, 255, 0, 128]).unwrap();
        let pixels = zl.finish().unwrap();

        let layer = |visible: bool| {
            let mut d = vec![];
            d.extend((if visible { 1u16 } else { 0 }).to_le_bytes());
            d.extend(0u16.to_le_bytes()); // normal
            d.extend(0u16.to_le_bytes()); // level
            d.extend([0u8; 6]);
            d.push(255);
            d.extend([0u8; 3]);
            d.extend(1u16.to_le_bytes());
            d.push(b'L');
            d
        };
        let mut cel = vec![];
        cel.extend(0u16.to_le_bytes()); // layer 0
        cel.extend(0i16.to_le_bytes());
        cel.extend(0i16.to_le_bytes());
        cel.push(255);
        cel.extend(2u16.to_le_bytes()); // compressed
        cel.extend([0u8; 7]);
        cel.extend(2u16.to_le_bytes());
        cel.extend(1u16.to_le_bytes());
        cel.extend(pixels);
        // A cel on the hidden layer that would paint everything blue.
        let mut hidden = vec![];
        hidden.extend(1u16.to_le_bytes());
        hidden.extend([0u8; 4]);
        hidden.push(255);
        hidden.extend(0u16.to_le_bytes()); // raw
        hidden.extend([0u8; 7]);
        hidden.extend(2u16.to_le_bytes());
        hidden.extend(1u16.to_le_bytes());
        hidden.extend([0, 0, 255, 255, 0, 0, 255, 255]);

        let chunk = |kind: u16, body: Vec<u8>| {
            let mut c = vec![];
            c.extend(((body.len() + 6) as u32).to_le_bytes());
            c.extend(kind.to_le_bytes());
            c.extend(body);
            c
        };
        let mut chunks = vec![];
        chunks.extend(chunk(0x2004, layer(true)));
        chunks.extend(chunk(0x2004, layer(false)));
        chunks.extend(chunk(0x2005, cel));
        chunks.extend(chunk(0x2005, hidden));

        let mut frame = vec![];
        frame.extend(((chunks.len() + 16) as u32).to_le_bytes());
        frame.extend(0xF1FAu16.to_le_bytes());
        frame.extend(4u16.to_le_bytes());
        frame.extend(100u16.to_le_bytes());
        frame.extend([0u8; 2]);
        frame.extend(4u32.to_le_bytes());
        frame.extend(chunks);

        let mut h = vec![];
        h.extend(0u32.to_le_bytes());
        h.extend(0xA5E0u16.to_le_bytes());
        h.extend(1u16.to_le_bytes()); // frames
        h.extend(2u16.to_le_bytes()); // width
        h.extend(1u16.to_le_bytes()); // height
        h.extend(32u16.to_le_bytes());
        h.extend(1u32.to_le_bytes()); // layer opacity valid
        h.resize(128, 0);
        h.extend(frame);
        h
    }

    fn decode(png_bytes: &[u8]) -> (u32, u32, Vec<u8>) {
        let dec = png::Decoder::new(std::io::Cursor::new(png_bytes));
        let mut reader = dec.read_info().unwrap();
        let mut buf = vec![0; reader.output_buffer_size().unwrap()];
        let info = reader.next_frame(&mut buf).unwrap();
        buf.truncate(info.buffer_size());
        (info.width, info.height, buf)
    }

    #[test]
    fn aseprite_first_frame_renders_visible_layers() {
        let png_bytes = render_aseprite(sprite()).unwrap();
        let (w, h, px) = decode(&png_bytes);
        assert_eq!((w, h), (2, 1));
        assert_eq!(px, vec![255, 0, 0, 255, 0, 255, 0, 128]);
    }

    #[test]
    fn non_aseprite_data_is_refused() {
        assert!(render_aseprite(b"not a sprite at all".to_vec()).is_err());
        assert!(
            render_aseprite(sprite()[..60].to_vec()).is_err(),
            "truncated"
        );
    }

    #[test]
    fn working_and_commit_versions() {
        let t = TestRepo::new("main");
        let first = t.commit_file("img.bin", "abcd", "add image");
        t.write("img.bin", "zz");

        let v = working_file_versions(t.path(), "img.bin".into(), false).unwrap();
        assert_eq!(v.before.data.as_deref(), Some(&b"abcd"[..]));
        assert_eq!(v.after.data.as_deref(), Some(&b"zz"[..]));

        let v = working_file_versions(t.path(), "img.bin".into(), true).unwrap();
        assert_eq!(v.before.data, v.after.data, "nothing staged yet");

        let v = commit_file_versions(t.path(), first.to_string(), "img.bin".into(), None).unwrap();
        assert!(!v.before.exists, "added in this commit");
        assert_eq!(v.after.size, 4);

        t.write("new.bin", "7");
        let v = working_file_versions(t.path(), "new.bin".into(), false).unwrap();
        assert!(!v.before.exists);
        assert_eq!(v.after.data.as_deref(), Some(&b"7"[..]));
    }
}

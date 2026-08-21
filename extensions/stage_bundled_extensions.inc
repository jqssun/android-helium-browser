#include "base/files/file_path.h"
#include "base/values.h"
#include "build/build_config.h"

#if BUILDFLAG(IS_ANDROID)

#include <optional>
#include <string>
#include <string_view>

#include "base/android/apk_assets.h"
#include "base/containers/span.h"
#include "base/files/file.h"
#include "base/files/file_util.h"
#include "base/files/memory_mapped_file.h"
#include "base/json/json_reader.h"
#include "base/strings/strcat.h"
#include "chrome/common/chrome_paths.h"

namespace {

constexpr char kBundledAssetDir[] = "assets/extensions/";
constexpr char kBundledIndexAsset[] = "bundled.json";

int OpenBundledAsset(std::string_view name,
                     base::MemoryMappedFile::Region* region) {
  *region = base::MemoryMappedFile::Region::kWholeFile;
  return base::android::OpenApkAsset(base::StrCat({kBundledAssetDir, name}),
                                     region);
}

bool ReadBundledAsset(std::string_view name, std::string* contents) {
  base::MemoryMappedFile::Region region;
  int fd = OpenBundledAsset(name, &region);
  if (fd < 0) {
    return false;
  }
  base::File file(fd);
  contents->resize(region.size);
  return file.ReadAndCheck(region.offset,
                           base::as_writable_byte_span(*contents));
}

void StageBundledAsset(std::string_view name, const base::FilePath& path) {
  base::MemoryMappedFile::Region region;
  int fd = OpenBundledAsset(name, &region);
  if (fd < 0) {
    return;
  }
  base::File file(fd);
  std::optional<int64_t> existing = base::GetFileSize(path);
  if (existing.has_value() && *existing == static_cast<int64_t>(region.size)) {
    return;
  }
  std::string contents;
  contents.resize(region.size);
  if (file.ReadAndCheck(region.offset,
                        base::as_writable_byte_span(contents)) &&
      base::CreateDirectory(path.DirName())) {
    base::WriteFile(path, contents);
  }
}

void StageBundledExtensions(int base_path_id,
                            const base::FilePath& dir,
                            base::DictValue& prefs) {
  std::string index;
  if (base_path_id != chrome::DIR_EXTERNAL_EXTENSIONS ||
      !ReadBundledAsset(kBundledIndexAsset, &index)) {
    return;
  }
  std::optional<base::DictValue> parsed =
      base::JSONReader::ReadDict(index, base::JSON_PARSE_RFC);
  if (!parsed) {
    return;
  }

  for (auto entry : *parsed) {
    const base::DictValue* item = entry.second.GetIfDict();
    const std::string* crx = item ? item->FindString("external_crx") : nullptr;
    if (!crx) {
      continue;
    }
    base::FilePath relative(*crx);
    if (!relative.ReferencesParent() && !relative.IsAbsolute()) {
      StageBundledAsset(*crx, dir.Append(relative));
    }
  }

  prefs.Merge(std::move(*parsed));
}

}

#else

namespace {
void StageBundledExtensions(int, const base::FilePath&, base::DictValue&) {}
}

#endif

from pathlib import Path

p = Path("build-android-remote.yml")
s = p.read_text()

start = s.index("      - name: Find APK")
end = s.index("      - name:", start + 10)

block = """      - name: Find APK
        run: |
          find "$GITHUB_WORKSPACE/collabora-online" \\
            -type f \\
            \\( -name "*.apk" -o -name "*.aab" -o -name "*.aar" \\) \\
            -print

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: TayyibWord-ARM64-APK
          path: |
            collabora-online/**/*.apk
            collabora-online/**/*.aab
            collabora-online/android/lib/build/outputs/aar/*.aar
          if-no-files-found: error
"""

p.write_text(s[:start] + block + s[end:])
print("FIXED")

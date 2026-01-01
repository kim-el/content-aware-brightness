# How to Publish Your Homebrew Tap 🍺

## 1. Create the Tap Repository
1.  Go to GitHub and create a **new repository**.
2.  Name it exactly: `homebrew-tap`
    *   (So your full URL is `github.com/kim-el/homebrew-tap`)

## 2. Prepare the Release
1.  Go to the `content-aware-brightness` repo on GitHub.
2.  Click **Releases** -> **Draft a new release**.
3.  Tag version: `v3.0`
4.  Upload the zip file: `build/ContentAwareBrightness_v3.0.zip`.
5.  Publish it.
6.  **Copy the Link** to the zip file.

## 3. Update the Formula
1.  Open `homebrew/Casks/content-aware-brightness.rb`.
2.  **Calculate Hash:** Run this in terminal:
    ```bash
    shasum -a 256 build/ContentAwareBrightness_v3.0.zip
    ```
3.  **Update File:**
    *   Replace `:no_check` with `"YOUR_HASH_HERE"`.
    *   Uncomment the `url` line pointing to GitHub.
    *   Comment out the `url` line pointing to `file://`.

## 4. Push the Tap
1.  Locally, initialize the tap repo:
    ```bash
    cd homebrew
    git init
    git remote add origin https://github.com/kim-el/homebrew-tap.git
    git branch -M main
    git add .
    git commit -m "Add content-aware-brightness cask"
    git push -u origin main
    ```

## 5. Share It!
Now anyone can install it:

```bash
brew tap kim-el/tap
brew install --cask content-aware-brightness
```

--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}

import Data.Functor.Identity (runIdentity)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as T
import Hakyll
import System.Environment (getEnv)
import System.FilePath (replaceDirectory, replaceExtension, takeDirectory)
import System.IO.Unsafe (unsafePerformIO)
import qualified System.Process as Process
import Text.Pandoc (
    WriterOptions (
        writerHighlightStyle,
        writerNumberSections,
        writerTOCDepth,
        writerTableOfContents,
        writerTemplate
    ),
 )
import qualified Text.Pandoc as Pandoc
import Text.Pandoc.Templates (Template, compileTemplate)

--------------------------------------------------------------------------------

main :: IO ()
main = hakyllWith config $ do
    let individualPatterns = fromList ["about.org", "contact.org", "links.org", "documents/cv.org"]
    let copyPatterns = fromList ["images/**", "fonts/*", "documents/*"]

    match "images/**" $ do
        route idRoute
        compile copyFileCompiler

    match "fonts/*" $ do
        route idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route idRoute
        compile compressCssCompiler

    match "scripts/**" $ do
        route idRoute
        compile copyFileCompiler

    match "*pdf" $ do
        route idRoute

    match individualPatterns $ do
        route $ setExtension "html"
        compile $
            pandocCompiler
                >>= loadAndApplyTemplate "templates/default.html" defaultCtx
                >>= relativizeUrls

    -- kindly stolen from https://github.com/jaspervdj/jaspervdj/blob/b2a9a34cd2195c6e216b922e152c42266dded99d/src/Main.hs#L163-L169
    -- also see helper functions writeXetex and xelatex
    match "documents/cv.org" $
        version "pdf" $ do
            route $ setExtension "pdf"
            compile $
                getResourceBody
                    >>= readPandoc
                    >>= writeXeTex
                    >>= loadAndApplyTemplate "templates/cv.tex" defaultCtx
                    >>= xelatex

    tags <- buildTags "posts/*" (fromCapture "archive/tags/*.html")

    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let tagCtx =
                    constField "title" title
                        <> constField "tag" tag
                        <> listField "posts" (postCtx tags) (return posts)
                        <> defaultCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html" tagCtx
                >>= loadAndApplyTemplate "templates/default.html" tagCtx
                >>= relativizeUrls

    match "posts/*org" $ do
        route $ setExtension "html"
        compile $ do
            identifier <- getUnderlying
            toc <- getMetadataField identifier "enabletoc"
            numbering <- getMetadataField identifier "enablenumbering"
            let writerOptions' = maybe defaultHakyllWriterOptions (const $ writerOptions $ isJust numbering) toc
            pandocCompilerWith defaultHakyllReaderOptions writerOptions'
                >>= saveSnapshot "content"
                >>= loadAndApplyTemplate "templates/post.html" (postCtx tags)
                >>= loadAndApplyTemplate "templates/default.html" (postCtx tags)
                >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" (postCtx tags) (return posts)
                        <> constField "title" "Archives"
                        <> field "tags" (\_ -> renderTagList tags)
                        <> defaultCtx

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            let indexCtx = defaultCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx tags <> bodyField "description"
            posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*" "content"
            renderRss rssFeedConfiguration feedCtx posts

    -- https://robertwpearce.com/hakyll-pt-2-generating-a-sitemap-xml-file.html
    create ["sitemap.xml"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            individualPages <- loadAll individualPatterns
            let pages = posts <> individualPages
                sitemapCtx =
                    listField "pages" (postCtx tags) (return pages)
                        <> defaultCtx
            makeItem ""
                >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

    match "templates/*" $ compile templateBodyCompiler
  where
    -- https://github.com/jaspervdj/jaspervdj/blob/b2a9a34cd2195c6e216b922e152c42266dded99d/src/Main.hs#L214-L218
    writeXeTex :: Item Pandoc.Pandoc -> Compiler (Item String)
    writeXeTex = traverse $ \pandoc ->
        case Pandoc.runPure (Pandoc.writeLaTeX Pandoc.def pandoc) of
            Left err -> fail $ show err
            Right x -> return (T.unpack x)

    -- https://github.com/jaspervdj/jaspervdj/blob/b2a9a34cd2195c6e216b922e152c42266dded99d/src/Main.hs#L280-L292
    -- but even more hacky
    xelatex :: Item String -> Compiler (Item TmpFile)
    xelatex item = do
        TmpFile texPath <- newTmpFile "xelatex.tex"
        let tmpDir = takeDirectory texPath
            pdfPath = replaceExtension texPath "pdf"

        unsafeCompiler $ do
            writeFile texPath $ itemBody item
            let x = itemBody item
            _ <-
                Process.system $
                    unwords
                        [ "xelatex"
                        , "-halt-on-error"
                        , "-output-directory"
                        , tmpDir
                        , texPath
                        , ">/dev/null"
                        , "2>&1"
                        ]
            return ()

        makeItem $ TmpFile pdfPath

rssFeedConfiguration :: FeedConfiguration
rssFeedConfiguration =
    FeedConfiguration
        { feedTitle = "nattopages"
        , feedDescription = "Pages by natto"
        , feedAuthorName = "Amneesh Singh"
        , feedAuthorEmail = "natto@weirdnatto.in"
        , feedRoot = "https://weirdnatto.in"
        }

config :: Configuration
config =
    defaultConfiguration
        { deployCommand = "rsync --checksum -ave 'ssh -p" ++ sshTargetPort ++ "' _site/* " ++ sshTarget
        , previewPort = 3333
        }
  where
    {-# NOINLINE sshTarget #-}
    sshTarget = unsafePerformIO $ getEnv "SSHTARGET"
    {-# NOINLINE sshTargetPort #-}
    sshTargetPort = unsafePerformIO $ getEnv "SSHTARGETPORT"

postCtx :: Tags -> Context String
postCtx tags =
    tagsField "tags" tags
        --    <> teaserFieldWithSeparator "((.tease.))" "teaser" "content"
        <> dateField "date" "%B %e, %Y"
        <> dateField "altdate" "%Y-%m-%d"
        <> teaserField "teaser" "content"
        <> defaultCtx

defaultCtx :: Context String
defaultCtx =
    listField "subdomains" subCtx (return subdomains)
        <> domainCtx
        <> defaultContext
  where
    domain :: String
    domain = "weirdnatto.in"
    subCtx :: Context String
    subCtx =
        field "name" (return . itemBody)
            <> domainCtx
    domainCtx :: Context String
    domainCtx = constField "domain" domain
    subdomains :: [Item String]
    subdomains = map mkItem ["git", "radio", "f"]
      where
        mkItem :: a -> Item a
        mkItem a = Item{itemIdentifier = "subdomain", itemBody = a}

writerOptions :: Bool -> WriterOptions
writerOptions withNumbering =
    defaultHakyllWriterOptions
        { writerNumberSections = withNumbering
        , writerTableOfContents = True
        , writerTOCDepth = 2
        , writerTemplate = Just tocTemplate
        }

tocTemplate :: Text.Pandoc.Templates.Template Text
tocTemplate =
    either error id . runIdentity . compileTemplate "" $
        T.unlines
            [ "<div class=\"toc\"><div class=\"toc-header\">Table of Contents</div>"
            , "$toc$"
            , "</div>"
            , "$body$"
            ]

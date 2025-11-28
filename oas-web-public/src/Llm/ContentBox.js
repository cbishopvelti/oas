import { bundledThemes } from "shiki/themes";
import parseHtml from "html-react-parser";
import { getHighlighterCore, getSingletonHighlighterCore } from "shiki/core";
import { bundledLanguagesInfo } from "shiki/langs";
import getWasm from "shiki/wasm";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import {
  loadHighlighter,
  useCodeBlockToHtml,
  allLangs,
  allLangsAlias,
} from "@llm-ui/code";
import { markdownLookBack } from "@llm-ui/markdown";
import {
  codeBlockLookBack,
  findCompleteCodeBlock,
  findPartialCodeBlock,
} from "@llm-ui/code";
import { useLLMOutput, useStreamExample, throttleBasic } from "@llm-ui/react";
import { memoize, startsWith, find, last } from 'lodash'
import { memo } from 'react';

export const MarkdownComponent = ({ blockMatch }) => {
  const markdown = blockMatch.output;
  return <ReactMarkdown remarkPlugins={[remarkGfm]}>{markdown}</ReactMarkdown>;
};


export const highlighter = memoize(() => {
  // This is slow
  return loadHighlighter(
    getSingletonHighlighterCore({
      langs: allLangs(bundledLanguagesInfo),
      langAlias: allLangsAlias(bundledLanguagesInfo),
      themes: Object.values(bundledThemes),
      loadWasm: getWasm,
    }),
  );
})


export const codeToHtmlOptions = {
  theme: "github-light",
};

// Customize this component with your own styling
export const CodeBlock = ({ blockMatch }) => {
  const { html, code } = useCodeBlockToHtml({
    markdownCodeBlock: blockMatch.output,
    highlighter: highlighter(),
  });
  if (!html) {
    // fallback to <pre> if Shiki is not loaded yet
    return (
      <pre className="shiki">
        <code>{code}</code>
      </pre>
    );
  }
  return <>{parseHtml(html)}</>;
};

export const LLMOutputOpitons = {
  fallbackBlock: {
    component: MarkdownComponent,
    lookBack: markdownLookBack(),
  },
  blocks: [
    {
      component: CodeBlock,
      findCompleteMatch: findCompleteCodeBlock(),
      findPartialMatch: findPartialCodeBlock(),
      lookBack: codeBlockLookBack(),
    },
  ],
  isStreamFinished: true,
  // throttle: throttleBasic({
  //   readAheadChars: 1,
  //   targetBufferChars: 1,
  //   adjustPercentage: 1,
  //   frameLookBackMs: 0,
  //   windowLookBackMs: 0,
  // })
  throttle: (params) => {
    return {
      visibleTextIncrement: 9999999
    }
  }
}

const maybeGetName = (message) => {
  if (startsWith(message.metadata?.member?.presence_id, "anonymous")) {
    return message.metadata.member.presence_id
  }

  return message.metadata?.member?.name
}

export const ContentBox = memo(({
  message
}) => {
  const contentItem = find(message.content || [], (item) => item.type === undefined || item.type === "text")

  const { blockMatches } = useLLMOutput({
    llmOutput: (contentItem || {}).content || "",
    ...LLMOutputOpitons
  });

  if (!contentItem) {
    return <></>
  }

  const name = maybeGetName(message)

  return <div style={{
    marginRight: message.isMe === true ? "" : "20%",
    marginLeft: message.isMe === true ? "20%": ""
  }} >
    <div className="llm-content">
      {blockMatches.map((blockMatch, index) => {
        const Component = blockMatch.block.component;
        return <Component key={index} blockMatch={blockMatch} />;
      })}
    </div>
    <div style={{ textAlign: "right" }}>{ name || message.role}</div>
  </div>
})

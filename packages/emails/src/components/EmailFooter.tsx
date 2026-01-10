import { COMPANY_LOGO_URL, SOURCE_CODE_URL, WEBAPP_URL } from "@calcom/lib/constants";

import RawHtml from "./RawHtml";
import Row from "./Row";

const CommentIE = ({ html = "" }: { html?: string }) => (
  <RawHtml html={`<!--[if mso | IE]>${html}<![endif]-->`} />
);

interface EmailFooterProps {
  isWhiteLabeled?: boolean;
}

const EmailFooter = ({ isWhiteLabeled = false }: EmailFooterProps) => {
  const image = COMPANY_LOGO_URL;

  return (
    <>
      <CommentIE
        html={`</td></tr></table><table align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600" ><tr><td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;"></td>`}
      />
      <div style={{ margin: "0px auto", maxWidth: 600 }}>
        <Row align="center" border="0" style={{ width: "100%" }}>
          <td
            style={{
              direction: "ltr",
              fontSize: "0px",
              padding: "0px",
              textAlign: "center",
            }}>
            <CommentIE
              html={`<table role="presentation" border="0" cellpadding="0" cellspacing="0"><tr><td style="vertical-align:top;width:600px;" >`}
            />
            <div
              className="mj-column-per-100 mj-outlook-group-fix"
              style={{
                fontSize: "0px",
                textAlign: "left",
                direction: "ltr",
                display: "inline-block",
                verticalAlign: "top",
                width: "100%",
              }}>
              <Row border="0" style={{ verticalAlign: "top" }} width="100%">
                <td
                  align="center"
                  style={{
                    fontSize: "0px",
                    padding: "10px 25px",
                    paddingTop: "32px",
                    wordBreak: "break-word",
                  }}>
                  <Row border="0" style={{ borderCollapse: "collapse", borderSpacing: "0px" }}>
                    <td style={{ width: "89px" }}>
                      <a href={WEBAPP_URL} target="_blank" rel="noreferrer">
                        <img
                          height="19"
                          src={image}
                          style={{
                            border: "0",
                            display: "block",
                            outline: "none",
                            textDecoration: "none",
                            height: "19px",
                            width: "100%",
                            fontSize: "13px",
                          }}
                          width="89"
                          alt=""
                        />
                      </a>
                    </td>
                  </Row>
                </td>
              </Row>
              {/* Source code attribution for license compliance */}
              {isWhiteLabeled && (
                <Row border="0" style={{ verticalAlign: "top" }} width="100%">
                  <td
                    align="center"
                    style={{
                      fontSize: "0px",
                      padding: "8px 25px",
                      paddingBottom: "24px",
                      wordBreak: "break-word",
                    }}>
                    <div
                      style={{
                        fontFamily: "Roboto, Helvetica, sans-serif",
                        fontSize: "11px",
                        lineHeight: "16px",
                        textAlign: "center",
                        color: "#6B7280",
                      }}>
                      Powered by{" "}
                      <a
                        href={SOURCE_CODE_URL}
                        target="_blank"
                        rel="noreferrer"
                        style={{
                          color: "#6B7280",
                          textDecoration: "underline",
                        }}>
                        open source scheduling software
                      </a>
                    </div>
                  </td>
                </Row>
              )}
            </div>
            <CommentIE html="</td></tr></table>" />
          </td>
        </Row>
      </div>
    </>
  );
};

export default EmailFooter;

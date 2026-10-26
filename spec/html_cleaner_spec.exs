defmodule HtmlCleanerSpec do
  use ESpec

  describe "clean_html" do
    it "should keep valid markup" do
      expect(HtmlCleaner.clean_html("<div>This should be <strong>okay</strong></div>"))
      |> to(eq("<div>This should be <strong>okay</strong></div>"))
    end

    @example_html """
    <h3 class="test" id="test">Title</h3>
    <iframe src="https://external-site.com/"></iframe>
    <img src="https://example.de/logos/test.png">
    <img src="https://example.xxx/logos/test.png">
    <img src="https://media.example.com/logos/test.png">
    <p><img src="/logos/test.png"></p>
    <p><img src="https://external-site.com/track.png"></p>
    <img src="//external-site.com/track.png">
    <title>Title</title>
    <div class="testing" data-test="test">
      <p></p>
      <p>
        Test
        <br>

        <br>&nbsp;
        <br>
        There should be only one br
      </p>
      <p>  </p>
      <p>  &nbsp; </p>
      <a href="javascript:alert('oops');" target="_blank" rel="noopener noreferrer">Evil</a>
      <a href="/test">Test</a>
      <a href="/test" target="_blank">Test</a>
      <link href="/test.css" rel="stylesheet">
    </div>
    """

    it "should filter forbidden elements, properties, sources" do
      @example_html
      |> HtmlCleaner.clean_html()
      |> expect()
      |> to(
        eq("""
        <h3>Title</h3>\
        <div>\
        <p>
        Test
        <br/>\
         \

        There should be only one br
        </p>\
        <a href="#" target="_blank" rel="noopener noreferrer">Evil</a>\
        <a target="_blank" rel="noopener noreferrer" href="/test">Test</a>\
        <a rel="noopener noreferrer" href="/test" target="_blank">Test</a>\
        </div>\
        """)
      )
    end

    context "when allow_url_regex is specified" do
      it "should allow certain urls" do
        @example_html
        |> HtmlCleaner.clean_html(allowed_url_regex: ~r/^(https:\/\/([^\/]+\.)?example\
\.(at|be|be|ca|ca|ch|ch|ch|cl|cn|co|com(\.(ar|br|pe|tr))?\
|cz|de|dk|es|fi|fr|hk|hu|ie|in|info|it|jp|lu|mx|nl|no|nz|pl|pt|ru|se|uk))?\
\/[^\/]/)
        |> expect()
        |> to(
          eq("""
          <h3>Title</h3>\
          <img src="https://example.de/logos/test.png"/>\
          <img src="https://media.example.com/logos/test.png"/>\
          <p><img src="/logos/test.png"/></p>\
          <div>\
          <p>
          Test
          <br/>\
           \

          There should be only one br
          </p>\
          <a href="#" target="_blank" rel="noopener noreferrer">Evil</a>\
          <a target="_blank" rel="noopener noreferrer" href="/test">Test</a>\
          <a rel="noopener noreferrer" href="/test" target="_blank">Test</a>\
          </div>\
          """)
        )
      end
    end

    context "when allowed_elements is specified" do
      it "should allow certain elements" do
        @example_html
        |> HtmlCleaner.clean_html(
          allowed_url_regex: ~r/^https:\/\/external-site\.com\/$/,
          allowed_elements: ["iframe"]
        )
        |> expect()
        |> to(
          eq("""
          <h3>Title</h3>\
          <iframe src=\"https://external-site.com/\"></iframe>\
          <div>\
          <p>
          Test
          <br/>\
           \

          There should be only one br
          </p>\
          <a href="#" target="_blank" rel="noopener noreferrer">Evil</a>\
          <a target="_blank" rel="noopener noreferrer" href="/test">Test</a>\
          <a rel="noopener noreferrer" href="/test" target="_blank">Test</a>\
          </div>\
          """)
        )
      end
    end

    context "when an anchor href uses a scheme that is not allowed" do
      for href <- [
            "javascript:alert(1)",
            "JavaScript:alert(1)",
            " javascript:alert(1)",
            "&#x01;javascript:alert(1)",
            "java&#x09;script:alert(1)",
            "java&#x0A;script:alert(1)",
            "java&#x0D;script:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "vbscript:msgbox(1)"
          ] do
        it "should replace #{inspect(href)} with #" do
          ~s(<a href="#{unquote(href)}">x</a>)
          |> HtmlCleaner.clean_html()
          |> expect()
          |> to(eq(~s(<a target="_blank" rel="noopener noreferrer" href="#">x</a>)))
        end
      end
    end

    context "when an anchor href uses an allowed scheme or is relative" do
      for href <- [
            "https://example.com/jobs",
            "HTTPS://example.com/jobs",
            "http://example.com/jobs",
            "mailto:jobs@example.com",
            "tel:+31201234567",
            "/jobs",
            "jobs?page=2",
            "#apply"
          ] do
        it "should keep #{inspect(href)}" do
          ~s(<a href="#{unquote(href)}">x</a>)
          |> HtmlCleaner.clean_html()
          |> expect()
          |> to(
            eq(~s(<a target="_blank" rel="noopener noreferrer" href="#{unquote(href)}">x</a>))
          )
        end
      end
    end

    context "when allowed_classes_regex is specified" do
      it "should allow certain urls" do
        """
        <div class=" something  otherthing "></div>
        <div class=" totallydifferent "></div>
        """
        |> HtmlCleaner.clean_html(allowed_classes_regex: ~r/^something$/)
        |> expect()
        |> to(
          eq("""
          <div class="something"></div>\
          <div></div>\
          """)
        )
      end
    end

    context "when allowed_inline_style_properties" do
      it "should allow inline style properties" do
        """
        <div style="text-align: center;">I am centered</div>
        <div style="text-decoration: underline;">I am underlined</div>
        <div style="text-decoration: underline; background-color: red;">I am underlined with red background</div>
        <div style="color: yellow">I am yellow</div>
        <div></div>
        """
        |> HtmlCleaner.clean_html(
          allowed_inline_style_properties: [
            "text-decoration",
            "text-align"
          ]
        )
        |> expect()
        |> to(
          eq("""
          <div style="text-align: center">I am centered</div>\
          <div style="text-decoration: underline">I am underlined</div>\
          <div style="text-decoration: underline">I am underlined with red background</div>\
          <div>I am yellow</div>\
          <div></div>\
          """)
        )
      end
    end
  end
end

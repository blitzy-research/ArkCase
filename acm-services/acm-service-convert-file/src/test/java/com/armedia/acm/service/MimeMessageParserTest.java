package com.armedia.acm.service;

/*-
 * #%L
 * ACM Service: File Converting Service
 * %%
 * Copyright (C) 2014 - 2019 ArkCase LLC
 * %%
 * This file is part of the ArkCase software. 
 * 
 * If the software was purchased under a paid ArkCase license, the terms of 
 * the paid license agreement will prevail.  Otherwise, the software is 
 * provided under the following open source license terms:
 * 
 * ArkCase is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *  
 * ArkCase is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with ArkCase. If not, see <http://www.gnu.org/licenses/>.
 * #L%
 */

import static org.easymock.EasyMock.expect;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.easymock.EasyMockSupport;
import org.junit.Before;
import org.junit.Test;

import javax.mail.BodyPart;
import javax.mail.Multipart;
import javax.mail.Part;

import java.io.ByteArrayInputStream;
import java.util.HashMap;

/**
 * Unit tests for {@link MimeMessageParser#getInlineImageMap(Part)}.
 * <p>
 * The subject of these tests is the inline-image path, whose content cast no longer names the JavaMail
 * provider's internal Base64 decoder-stream class. That vendor-internal type is what the migration's static audit
 * of JDK-internal references had to clear, and dropping it from the source is only safe because nothing on the
 * path needs decoder-specific behaviour: the value is immediately drained into a byte array (the decoder stream
 * was itself only a filter stream). So the tests feed the parser a {@link Part} whose {@code getContent()} yields
 * a plain {@link ByteArrayInputStream} - a value the old implementation-class cast would have rejected with a
 * {@link ClassCastException} - and assert the bytes survive intact through Base64 encoding, that the map key is
 * the raw {@code Content-Id} header value, and that the recorded content type is the part's own.
 * <p>
 * Dropping the implementation class did NOT relax which parts are accepted. The Java 8 base commit only ever
 * accepted base64-encoded inline images, because it checkcast the decoded content to the provider's base64
 * decoder stream, so the parser still requires the part to declare {@code base64} as its content transfer
 * encoding and still rejects every other encoding with a {@link ClassCastException} at the same point. The
 * qualifying parts below therefore declare that encoding, and
 * {@link #inlineImageWithANonBase64TransferEncodingIsRejected()} pins the rejection so the accepted-encoding set
 * cannot widen unnoticed.
 * <p>
 * The negative cases matter just as much: a part with no {@code Content-Id} and a non-image part must both be
 * skipped WITHOUT their content being read. Each such part is a mock with no {@code getContent()} expectation, so
 * an unexpected read fails the test outright rather than passing silently.
 */
public class MimeMessageParserTest extends EasyMockSupport
{
    private static final String CONTENT_ID = "<image001.png@01D2A2F0.1B2C3D40>";
    private static final String PNG_CONTENT_TYPE = "image/png; name=\"image001.png\"";

    /**
     * The header the parser reads to decide whether a part's decoded content is base64, and the only value it
     * accepts. A part that declares anything else carries content this path cannot re-encode faithfully.
     */
    private static final String CONTENT_TRANSFER_ENCODING = "Content-Transfer-Encoding";
    private static final String BASE64_ENCODING = "base64";

    /**
     * A byte sequence that is deliberately NOT valid UTF-8 (it opens with the PNG magic number and includes 0x00
     * and 0xFF), so any accidental conversion through a String would corrupt it and change the expected Base64.
     */
    private static final byte[] IMAGE_BYTES = new byte[] { (byte) 0x89, 'P', 'N', 'G', (byte) 0x0D, (byte) 0x0A,
            (byte) 0x1A, (byte) 0x0A, (byte) 0x00, (byte) 0xFF, (byte) 0x10 };

    /**
     * Base64 of IMAGE_BYTES, written out literally rather than computed with the same encoder the production code
     * uses, so the assertion is an independent statement of the expected payload.
     */
    private static final String IMAGE_BASE64 = "iVBORw0KGgoA/xA=";

    private Part imagePart;

    @Before
    public void setUp()
    {
        imagePart = createMock(Part.class);
    }

    /**
     * The single-part case: an image carrying a Content-Id is read through the widened cast, Base64-encoded and
     * keyed by the raw header value. {@code getContent()} is expected exactly once, which also pins that the
     * stream is drained in one pass.
     */
    @Test
    public void inlineImageIsReadFromAGenericInputStream() throws Exception
    {
        expect(imagePart.isMimeType("image/*")).andReturn(true);
        expect(imagePart.getHeader("Content-Id")).andReturn(new String[] { CONTENT_ID }).times(2);
        expect(imagePart.getContent()).andReturn(new ByteArrayInputStream(IMAGE_BYTES)).once();
        expect(imagePart.getHeader(CONTENT_TRANSFER_ENCODING)).andReturn(new String[] { BASE64_ENCODING });
        expect(imagePart.getContentType()).andReturn(PNG_CONTENT_TYPE);
        expect(imagePart.isMimeType("multipart/*")).andReturn(false);

        replayAll();

        HashMap<String, MimeObjectEntry<String>> inlineImages = MimeMessageParser.getInlineImageMap(imagePart);

        verifyAll();

        assertEquals(1, inlineImages.size());
        assertTrue("the raw Content-Id header value must be the map key", inlineImages.containsKey(CONTENT_ID));

        MimeObjectEntry<String> image = inlineImages.get(CONTENT_ID);
        assertEquals("the whole stream must be Base64-encoded byte for byte", IMAGE_BASE64, image.getEntry());
        assertEquals("image/png", image.getContentType().getBaseType());
        assertEquals("image001.png", image.getContentType().getParameter("name"));
    }

    /**
     * The accepted-encoding contract, pinned so it cannot widen unnoticed. The Java 8 base commit checkcast the
     * decoded content to the mail provider's base64 decoder stream, so a part declaring quoted-printable - or
     * uuencode, 7bit, 8bit, binary, or no encoding at all - aborted the conversion with a
     * {@link ClassCastException}. Removing the implementation-class reference from the source must not turn any of
     * those failures into a successfully embedded image, because that would change the rendered EML-to-PDF output.
     * The rejection also has to happen BEFORE the part is added to the map, which is what the empty result and the
     * absent content type assert.
     */
    @Test
    public void inlineImageWithANonBase64TransferEncodingIsRejected() throws Exception
    {
        expect(imagePart.isMimeType("image/*")).andReturn(true);
        expect(imagePart.getHeader("Content-Id")).andReturn(new String[] { CONTENT_ID }).times(2);
        expect(imagePart.getContent()).andReturn(new ByteArrayInputStream(IMAGE_BYTES)).once();
        expect(imagePart.getHeader(CONTENT_TRANSFER_ENCODING)).andReturn(new String[] { "quoted-printable" });
        expect(imagePart.getContentType()).andReturn(PNG_CONTENT_TYPE);

        replayAll();

        try
        {
            MimeMessageParser.getInlineImageMap(imagePart);
            fail("a part declaring a non-base64 content transfer encoding must be rejected, as it was on Java 8");
        }
        catch (ClassCastException e)
        {
            assertTrue("the failure must name the unsupported encoding: " + e.getMessage(),
                    e.getMessage().contains("quoted-printable"));
        }

        verifyAll();
    }

    /**
     * An image with no Content-Id cannot be referenced from the message body, so it is not an inline image. It
     * must be skipped before its content is touched - the mock declares no {@code getContent()} expectation, so
     * reading it would fail this test.
     */
    @Test
    public void imageWithoutContentIdIsSkippedWithoutBeingRead() throws Exception
    {
        expect(imagePart.isMimeType("image/*")).andReturn(true);
        expect(imagePart.getHeader("Content-Id")).andReturn(null);
        expect(imagePart.isMimeType("multipart/*")).andReturn(false);

        replayAll();

        HashMap<String, MimeObjectEntry<String>> inlineImages = MimeMessageParser.getInlineImageMap(imagePart);

        verifyAll();

        assertTrue("a part without a Content-Id is not an inline image", inlineImages.isEmpty());
    }

    /**
     * A non-image part is skipped even when it does carry a Content-Id, and again without being read: the
     * mime-type test short-circuits, so the header is never even consulted.
     */
    @Test
    public void nonImagePartIsSkippedWithoutBeingRead() throws Exception
    {
        Part textPart = createMock(Part.class);
        expect(textPart.isMimeType("image/*")).andReturn(false);
        expect(textPart.isMimeType("multipart/*")).andReturn(false);

        replayAll();

        HashMap<String, MimeObjectEntry<String>> inlineImages = MimeMessageParser.getInlineImageMap(textPart);

        verifyAll();

        assertTrue("a text part is never an inline image", inlineImages.isEmpty());
    }

    /**
     * The realistic shape: a multipart container whose children are one qualifying image and one text part. The
     * walk must recurse into the container, collect only the image, and leave the text part unread. The container
     * itself is also offered to the callback first, which is why it answers the image mime-type test too.
     */
    @Test
    public void multipartWalkCollectsOnlyQualifyingImageParts() throws Exception
    {
        BodyPart textBodyPart = createMock(BodyPart.class);
        expect(textBodyPart.isMimeType("image/*")).andReturn(false);
        expect(textBodyPart.isMimeType("multipart/*")).andReturn(false);

        BodyPart imageBodyPart = createMock(BodyPart.class);
        expect(imageBodyPart.isMimeType("image/*")).andReturn(true);
        expect(imageBodyPart.getHeader("Content-Id")).andReturn(new String[] { CONTENT_ID }).times(2);
        expect(imageBodyPart.getContent()).andReturn(new ByteArrayInputStream(IMAGE_BYTES)).once();
        expect(imageBodyPart.getHeader(CONTENT_TRANSFER_ENCODING)).andReturn(new String[] { BASE64_ENCODING });
        expect(imageBodyPart.getContentType()).andReturn(PNG_CONTENT_TYPE);
        expect(imageBodyPart.isMimeType("multipart/*")).andReturn(false);

        Multipart multipart = createMock(Multipart.class);
        // the walk re-reads the count on every iteration of its for-loop, so the call count is an implementation
        // detail rather than something worth pinning; the child lookups below are what the test is about
        expect(multipart.getCount()).andReturn(2).anyTimes();
        expect(multipart.getBodyPart(0)).andReturn(textBodyPart);
        expect(multipart.getBodyPart(1)).andReturn(imageBodyPart);

        Part container = createMock(Part.class);
        expect(container.isMimeType("image/*")).andReturn(false);
        expect(container.isMimeType("multipart/*")).andReturn(true);
        expect(container.getContent()).andReturn(multipart).once();

        replayAll();

        HashMap<String, MimeObjectEntry<String>> inlineImages = MimeMessageParser.getInlineImageMap(container);

        verifyAll();

        assertEquals("only the image child may be collected", 1, inlineImages.size());
        assertEquals(IMAGE_BASE64, inlineImages.get(CONTENT_ID).getEntry());
        assertFalse("the container itself must not be collected", inlineImages.containsKey(PNG_CONTENT_TYPE));
    }

    /**
     * The remaining walk-based entry points of the parser share the very same recursion as the inline-image path,
     * so they are covered here too: the body-part search must prefer html over plain regardless of the order the
     * two arrive in, and must record the winning part's own content type.
     */
    @Test
    public void findBodyPartPrefersHtmlOverPlainText() throws Exception
    {
        BodyPart plainPart = createMock(BodyPart.class);
        expect(plainPart.isMimeType("text/plain")).andReturn(true).anyTimes();
        expect(plainPart.isMimeType("text/html")).andReturn(false).anyTimes();
        expect(plainPart.isMimeType("multipart/*")).andReturn(false).anyTimes();
        expect(plainPart.getContent()).andReturn("the plain text alternative").once();
        expect(plainPart.getDisposition()).andReturn(null);
        expect(plainPart.getContentType()).andReturn("text/plain; charset=\"utf-8\"").anyTimes();

        BodyPart htmlPart = createMock(BodyPart.class);
        expect(htmlPart.isMimeType("text/plain")).andReturn(false).anyTimes();
        expect(htmlPart.isMimeType("text/html")).andReturn(true).anyTimes();
        expect(htmlPart.isMimeType("multipart/*")).andReturn(false).anyTimes();
        expect(htmlPart.getContent()).andReturn("<html><body>the html alternative</body></html>").once();
        expect(htmlPart.getDisposition()).andReturn(null);
        expect(htmlPart.getContentType()).andReturn("text/html; charset=\"utf-8\"").anyTimes();

        Multipart multipart = createMock(Multipart.class);
        expect(multipart.getCount()).andReturn(2).anyTimes();
        expect(multipart.getBodyPart(0)).andReturn(plainPart);
        expect(multipart.getBodyPart(1)).andReturn(htmlPart);

        Part container = createMock(Part.class);
        expect(container.isMimeType("text/plain")).andReturn(false).anyTimes();
        expect(container.isMimeType("text/html")).andReturn(false).anyTimes();
        expect(container.isMimeType("multipart/*")).andReturn(true).anyTimes();
        expect(container.getContent()).andReturn(multipart).once();

        replayAll();

        MimeObjectEntry<String> body = MimeMessageParser.findBodyPart(container);

        verifyAll();

        assertEquals("<html><body>the html alternative</body></html>", body.getEntry());
        assertEquals("text/html", body.getContentType().getBaseType());
    }

    /**
     * Attachment collection: a part disposed as an attachment qualifies, while an inline-disposed part does not,
     * even inside the same container.
     */
    @Test
    public void getAttachmentsCollectsOnlyAttachmentDisposedParts() throws Exception
    {
        BodyPart attachmentPart = createMock(BodyPart.class);
        expect(attachmentPart.getDisposition()).andReturn(Part.ATTACHMENT).anyTimes();
        expect(attachmentPart.isMimeType("multipart/*")).andReturn(false).anyTimes();

        BodyPart inlinePart = createMock(BodyPart.class);
        expect(inlinePart.getDisposition()).andReturn(Part.INLINE).anyTimes();
        expect(inlinePart.isMimeType("multipart/*")).andReturn(false).anyTimes();

        Multipart multipart = createMock(Multipart.class);
        expect(multipart.getCount()).andReturn(2).anyTimes();
        expect(multipart.getBodyPart(0)).andReturn(attachmentPart);
        expect(multipart.getBodyPart(1)).andReturn(inlinePart);

        Part container = createMock(Part.class);
        expect(container.getDisposition()).andReturn(null).anyTimes();
        expect(container.getFileName()).andReturn(null).anyTimes();
        expect(container.isMimeType("multipart/*")).andReturn(true).anyTimes();
        expect(container.getContent()).andReturn(multipart).once();

        replayAll();

        assertEquals("only the attachment-disposed child may be collected", 1,
                MimeMessageParser.getAttachments(container).size());
    }

    /**
     * The structure dump indents one level per nesting step and appends the disposition when the part declares
     * one, which is the diagnostic view of the same recursion the inline-image path walks.
     */
    @Test
    public void printStructureIndentsNestedPartsAndReportsDisposition() throws Exception
    {
        BodyPart attachmentPart = createMock(BodyPart.class);
        expect(attachmentPart.getContentType()).andReturn("text/plain; charset=\"utf-8\"").anyTimes();
        expect(attachmentPart.getHeader("Content-Disposition"))
                .andReturn(new String[] { "attachment; filename=\"notes.txt\"" }).anyTimes();
        expect(attachmentPart.isMimeType("multipart/*")).andReturn(false).anyTimes();

        Multipart multipart = createMock(Multipart.class);
        expect(multipart.getCount()).andReturn(1).anyTimes();
        expect(multipart.getBodyPart(0)).andReturn(attachmentPart);

        Part container = createMock(Part.class);
        expect(container.getContentType()).andReturn("multipart/mixed; boundary=\"----=_Part_1\"").anyTimes();
        expect(container.getHeader("Content-Disposition")).andReturn(null).anyTimes();
        expect(container.isMimeType("multipart/*")).andReturn(true).anyTimes();
        expect(container.getContent()).andReturn(multipart).once();

        replayAll();

        String structure = MimeMessageParser.printStructure(container);

        verifyAll();

        assertTrue("the container is reported at level 0", structure.contains("\n> multipart/mixed\n"));
        assertTrue("the child is reported one level in, with its disposition",
                structure.contains("\n> |  text/plain; attachment\n"));
    }
}

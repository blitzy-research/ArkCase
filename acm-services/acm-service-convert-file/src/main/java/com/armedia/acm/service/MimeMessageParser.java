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

import com.google.common.base.Strings;
import com.google.common.io.BaseEncoding;
import com.google.common.io.ByteStreams;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.safety.Whitelist;

import javax.mail.BodyPart;
import javax.mail.Message;
import javax.mail.MessagingException;
import javax.mail.Multipart;
import javax.mail.Part;
import javax.mail.internet.ContentDisposition;
import javax.mail.internet.ContentType;
import javax.mail.internet.MimePart;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * Utility class to parse a MimeMessage.
 * 
 * @author Nick Russler
 */
public class MimeMessageParser
{
    public static final String DEFAULT_EMAIL_MIME_TYPE = "message/rfc822";

    /**
     * Name of the MIME header through which a part declares how its content is encoded.
     */
    private static final String CONTENT_TRANSFER_ENCODING_HEADER = "Content-Transfer-Encoding";

    /**
     * The only content transfer encoding whose decoded content is accepted as an inline image.
     */
    private static final String BASE64_TRANSFER_ENCODING = "base64";

    private static Logger log = LogManager.getLogger(MimeMessageParser.class);

    /**
     * Walk the MIME structure recursively and execute the callback on every part, the given part included.
     * 
     * @param p
     *            mime object
     * @param level
     *            depth of the current part, incremented for each nested multipart level
     * @param callback
     *            object holding the callback function
     * @throws Exception
     *             whatever the callback throws, or a messaging or I/O failure while reading a multipart's content
     */
    private static void walkMimeStructure(Part p, int level, WalkMimeCallback callback) throws Exception
    {
        callback.walkMimeCallback(p, level);

        if (p.isMimeType("multipart/*"))
        {
            Multipart mp = (Multipart) p.getContent();
            for (int i = 0; i < mp.getCount(); i++)
            {
                walkMimeStructure(mp.getBodyPart(i), level + 1, callback);
            }
        }
    }

    /**
     * Print the structure of the Mime object.
     * 
     * @param p
     *            Mime object
     * @return one indented line per part, listing its base content type and, when present, its content disposition
     * @throws Exception
     *             on a messaging or I/O failure while walking the structure or reading a part's headers
     */
    public static String printStructure(Part p) throws Exception
    {
        final StringBuilder result = new StringBuilder();

        result.append("-----------Mime Message-----------\n");
        walkMimeStructure(p, 0, new WalkMimeCallback()
        {
            @Override
            public void walkMimeCallback(Part p, int level) throws Exception
            {
                String s = "> " + Strings.repeat("|  ", level) + new ContentType(p.getContentType()).getBaseType();

                String[] contentDispositionArr = p.getHeader("Content-Disposition");
                if (contentDispositionArr != null)
                {
                    s += "; " + new ContentDisposition(contentDispositionArr[0]).getDisposition();
                }

                result.append(s);
                result.append("\n");
            }
        });
        result.append("----------------------------------");

        return result.toString();
    }

    /**
     * Get the String Content of a MimePart.
     * 
     * @param p
     *            MimePart
     * @return the content as a String, or <code>null</code> when the part is neither a String nor a stream
     * @throws IOException
     *             if the part's raw stream cannot be read
     * @throws MessagingException
     *             if the part's raw stream cannot be obtained
     */
    private static String getStringContent(Part p) throws IOException, MessagingException
    {
        Object content = null;

        try
        {
            content = p.getContent();
        }
        catch (Exception e)
        {
            log.debug("Email body could not be read automatically (%s), we try to read it anyway.", e.toString());

            // Fall back to the undecoded stream, which is then read as UTF-8 below.
            content = p.getInputStream();
        }

        String stringContent = null;

        if (content instanceof String)
        {
            stringContent = (String) content;
        }
        else if (content instanceof InputStream)
        {
            stringContent = new String(ByteStreams.toByteArray((InputStream) content), "utf-8");
        }

        return stringContent;
    }

    /**
     * Find the main message body, preferring html over plain.
     * 
     * @param p
     *            mime object
     * @return the main message body and the corresponding contentType or an empty text/plain
     * @throws Exception
     *             on a messaging or I/O failure while walking the structure or reading a part's content
     */
    public static MimeObjectEntry<String> findBodyPart(Part p) throws Exception
    {
        final MimeObjectEntry<String> result = new MimeObjectEntry<>("", new ContentType("text/plain; charset=\"utf-8\""));

        walkMimeStructure(p, 0, new WalkMimeCallback()
        {
            @Override
            public void walkMimeCallback(Part p, int level) throws Exception
            {
                // only process text/plain and text/html
                if (!p.isMimeType("text/plain") && !p.isMimeType("text/html"))
                {
                    return;
                }

                String stringContent = getStringContent(p);
                boolean isAttachment = Part.ATTACHMENT.equalsIgnoreCase(p.getDisposition());

                if (Strings.isNullOrEmpty(stringContent) || isAttachment)
                {
                    return;
                }

                // use text/plain entries only when we found nothing before
                if (result.getEntry().isEmpty() || p.isMimeType("text/html"))
                {
                    result.setEntry(stringContent);
                    result.setContentType(new ContentType(p.getContentType()));
                }
            }
        });

        return result;
    }

    /**
     * Set the main message body to new string content. Only the first non-attachment text/html part is replaced; a
     * message without one is returned unchanged apart from having its multipart content set again.
     * 
     * @param message
     *            mime object
     * @param newStringContent
     *            new message text content
     * @return the changed message
     * @throws IOException
     *             if the message's content cannot be read
     * @throws MessagingException
     *             if the message is not multipart, or a part cannot be read or updated
     */
    public static Part setBodyPart(Part message, String newStringContent) throws IOException, MessagingException
    {
        Multipart multipart = (Multipart) message.getContent();

        for (int i = 0; i < multipart.getCount(); i++)
        {
            BodyPart bodyPart = multipart.getBodyPart(i);

            if (!Part.ATTACHMENT.equalsIgnoreCase(bodyPart.getDisposition()) && bodyPart.isMimeType("text/html"))
            {
                bodyPart.setText(newStringContent);
                break;
            }
        }

        message.setContent(multipart);
        return message;
    }

    /**
     * Get all inline images (images with a Content-Id) as a HashMap.
     * The key is the Content-Id and all images in all multipart containers are included in the map.
     * 
     * @param p
     *            mime object
     * @return HashMap&lt;Content-Id, &lt;Base64Image, ContentType&gt;&gt;
     * @throws Exception
     *             on a messaging or I/O failure while walking the structure or reading an image's content
     */
    public static HashMap<String, MimeObjectEntry<String>> getInlineImageMap(Part p) throws Exception
    {
        final HashMap<String, MimeObjectEntry<String>> result = new HashMap<>();

        walkMimeStructure(p, 0, new WalkMimeCallback()
        {
            @Override
            public void walkMimeCallback(Part p, int level) throws Exception
            {
                if (p.isMimeType("image/*") && (p.getHeader("Content-Id") != null))
                {
                    String id = p.getHeader("Content-Id")[0];

                    InputStream b64ds = getBase64DecodedContent(p);
                    String imageBase64 = BaseEncoding.base64().encode(ByteStreams.toByteArray(b64ds));
                    result.put(id, new MimeObjectEntry<>(imageBase64, new ContentType(p.getContentType())));
                }
            }
        });

        return result;
    }

    /**
     * Get the decoded content of an inline image part, accepting base64 encoded parts only.
     * <p>
     * This check is what the stream cast used to do implicitly. Until Java 17 the line above cast the content to
     * JavaMail's own base64 decoder-stream class, whose vendor-internal package name the JDK-internal-API audit forbids
     * naming in source; widening the cast to {@link InputStream} removed that name but also removed the only thing that
     * rejected a part whose content had been decoded from something other than base64. That is a behaviour change rather
     * than a cosmetic one, so the rejection is restored here explicitly.
     * <p>
     * Why only base64 is accepted: the caller re-encodes this content with
     * {@link com.google.common.io.BaseEncoding#base64()} and embeds the result in generated HTML. A part declaring any
     * other content transfer encoding - quoted-printable, uuencode, 7bit, 8bit or binary - is decoded by the mail
     * implementation into a different stream type, which the base64 cast never accepted, so admitting one now would be a
     * new capability rather than a preserved one. The encoding is read from the part's own declaration, which is the
     * same value the mail implementation consults when it chooses a decoder, so the two cannot disagree.
     * <p>
     * {@link ClassCastException} is raised deliberately, rather than a more descriptive exception type: it is exactly
     * what the cast raised, and <code>getInlineImageMap</code> is called from mail-conversion paths that already handle
     * it. Changing the type would change how those callers behave.
     *
     * @param p
     *            mime object holding an inline image
     * @return the decoded base64 content of the part
     * @throws ClassCastException
     *             if the part is not base64 encoded, or its decoded content is not a stream
     * @throws IOException
     *             if the content of the part cannot be read
     * @throws MessagingException
     *             if the part cannot be parsed
     */
    private static InputStream getBase64DecodedContent(Part p) throws IOException, MessagingException
    {
        Object content = p.getContent();
        String transferEncoding = getTransferEncoding(p);

        if (transferEncoding == null || !BASE64_TRANSFER_ENCODING.equalsIgnoreCase(transferEncoding.trim()))
        {
            throw new ClassCastException(String.format(
                    "Inline image of type [%s] declares content transfer encoding [%s], only [%s] is supported",
                    p.getContentType(), transferEncoding, BASE64_TRANSFER_ENCODING));
        }

        return (InputStream) content;
    }

    /**
     * Get the content transfer encoding a part declares for its content.
     * <p>
     * A {@link MimePart} is asked directly, because that is the accessor the mail implementation itself uses. Anything
     * else is asked for the raw header, so a hand-rolled {@link Part} implementation is handled too.
     *
     * @param p
     *            mime object
     * @return the declared content transfer encoding, or null when the part declares none
     * @throws MessagingException
     *             if the part cannot be parsed
     */
    private static String getTransferEncoding(Part p) throws MessagingException
    {
        if (p instanceof MimePart)
        {
            return ((MimePart) p).getEncoding();
        }

        String[] transferEncodingHeader = p.getHeader(CONTENT_TRANSFER_ENCODING_HEADER);

        if (transferEncodingHeader == null || transferEncodingHeader.length == 0)
        {
            return null;
        }

        return transferEncodingHeader[0];
    }

    public static List<Part> getAttachments(Part p) throws Exception
    {
        final List<Part> result = new ArrayList<>();

        walkMimeStructure(p, 0, new WalkMimeCallback()
        {
            @Override
            public void walkMimeCallback(Part p, int level) throws Exception
            {
                if (Part.ATTACHMENT.equalsIgnoreCase(p.getDisposition())
                        || ((p.getDisposition() == null) && !Strings.isNullOrEmpty(p.getFileName())))
                {
                    result.add(p);
                }
            }
        });

        return result;
    }

    /**
     * Converts the body content of emails from text/html email format to a formatted
     * string with carriage returns for element breaks. A body that cannot be read is logged and reported as an empty
     * string rather than raised.
     * 
     * @param message
     *            mime message
     * @return String formatted body content
     * @throws MessagingException
     *             if the message's subject cannot be read while reporting a body failure
     */
    public static String getFormattedStringContent(Message message) throws MessagingException
    {
        String formattedContent = "";
        try
        {
            MimeObjectEntry<String> bodyPart = MimeMessageParser.findBodyPart(message);

            Document jsoupDoc = Jsoup.parse(bodyPart.getEntry());

            Document.OutputSettings outputSettings = new Document.OutputSettings();
            outputSettings.prettyPrint(false);
            jsoupDoc.outputSettings(outputSettings);
            jsoupDoc.select("br").before("\\n");
            jsoupDoc.select("p").before("\\n");

            String str = jsoupDoc.html().replaceAll("\\\\n", "\r\n");

            formattedContent = Jsoup.clean(str, "", Whitelist.none(), outputSettings).trim();
        }
        catch (Exception e)
        {
            log.error("Couldn't read body of email with subject [{}]", message.getSubject(), e);

        }
        return formattedContent;
    }

    /**
     * Returns true if an email is the only attachment in a list of attachments
     * 
     * @param attachments
     *            Email attachments
     * @return boolean true if an email is the only attachment
     * @throws MessagingException
     *             if the single attachment's content type cannot be read
     */
    public static boolean hasForwardedEmailAsAttachment(List<Part> attachments) throws MessagingException
    {
        return attachments.size() == 1 && attachments.get(0).isMimeType(DEFAULT_EMAIL_MIME_TYPE);
    }

}

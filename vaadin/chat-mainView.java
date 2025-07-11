package com.example.application.views.main;

import com.vaadin.flow.component.applayout.AppLayout;
import com.vaadin.flow.component.html.H1;
import com.vaadin.flow.component.html.Image;
import com.vaadin.flow.component.icon.Icon;
import com.vaadin.flow.component.icon.VaadinIcon;
import com.vaadin.flow.component.messages.MessageInput;
import com.vaadin.flow.component.messages.MessageList;
import com.vaadin.flow.component.messages.MessageListItem;
import com.vaadin.flow.component.orderedlayout.HorizontalLayout;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.server.StreamResource;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@PageTitle("Chatbot")
@Route(value = "")
public class MainView extends VerticalLayout {

    public MainView() {
        // --- Logo and Header ---
        Image logo = new Image("images/logo.png", "My App Logo");
        logo.setHeight("50px");
        H1 title = new H1("Classic Chatbot");
        HorizontalLayout header = new HorizontalLayout(logo, title);
        header.setAlignItems(Alignment.CENTER);
        header.setSpacing(true);

        // --- Chat Window ---
        MessageList chatWindow = new MessageList();
        List<MessageListItem> messages = new ArrayList<>();

        // --- Initial Chatbot Message ---
        MessageListItem initialMessage = new MessageListItem(
                "Hello! How can I help you today?",
                Instant.now(),
                "Chatbot"
        );
        initialMessage.setUserAvatar(new Icon(VaadinIcon.AUTOMATION));
        messages.add(initialMessage);
        chatWindow.setItems(messages);

        // --- Message Input ---
        MessageInput messageInput = new MessageInput();
        messageInput.addSubmitListener(event -> {
            String userMessageText = event.getValue();

            // --- Display User Message ---
            MessageListItem userMessage = new MessageListItem(
                    userMessageText,
                    Instant.now(),
                    "You"
            );
            userMessage.setUserAvatar(new Icon(VaadinIcon.USER));
            userMessage.getStyle().set("align-self", "flex-end"); // Align user messages to the right
            messages.add(userMessage);
            chatWindow.setItems(new ArrayList<>(messages)); // Create a new list to trigger update

            // --- Simple Chatbot Response Logic ---
            String botResponseText = "I received your message: \"" + userMessageText + "\"";
            MessageListItem botMessage = new MessageListItem(
                    botResponseText,
                    Instant.now(),
                    "Chatbot"
            );
            botMessage.setUserAvatar(new Icon(VaadinIcon.AUTOMATION));
            messages.add(botMessage);
            chatWindow.setItems(new ArrayList<>(messages)); // Create a new list to trigger update
        });

        // --- Layout Configuration ---
        setSizeFull();
        add(header, chatWindow, messageInput);
        expand(chatWindow); // Make the chat window expand to fill available space
        setAlignItems(Alignment.STRETCH);
        setPadding(false);
        setSpacing(false);

        // Place your logo.png in the 'src/main/resources/META-INF/resources/images/' directory
    }
}

Building a Classic Chatbot Interface with Vaadin's MainView
This guide provides a comprehensive walkthrough to create a visually appealing and functional chatbot interface within a Vaadin MainView. The layout will feature a prominent logo at the top, a scrollable chat window displaying interactions with distinct user and chatbot icons, and a text input field for user queries.

Final Application Structure

The completed application will have the following structure:

MainView: The primary container for the entire chat interface, utilizing a VerticalLayout for top-to-bottom component arrangement.

Header: A HorizontalLayout at the top of the MainView to display the application logo and title.

Chat Window: A MessageList component to dynamically display the conversation history.

Message Bubbles: Individual MessageListItem objects within the MessageList, customized to differentiate between user and chatbot messages with unique icons.

Input Area: A MessageInput component at the bottom for users to type and submit their messages.

Step-by-Step Implementation

Here is the Vaadin Java code to construct the chatbot interface. This code can be placed within your project's MainView.java file.

Key Components and Concepts

VerticalLayout and HorizontalLayout: These are fundamental layout components in Vaadin for arranging other UI elements either vertically or horizontally.

Image: This component is used to display the application's logo. Ensure you place your logo.png file in the src/main/resources/META-INF/resources/images/ directory of your project.

MessageList: This component is specifically designed to display a list of messages, making it ideal for a chat interface.

MessageListItem: Each message in the MessageList is a MessageListItem. This object allows you to set the message text, timestamp, sender's name, and an avatar.

setUserAvatar(Component): This method of MessageListItem is crucial for displaying the user and chatbot icons. We use Vaadin's built-in Icon component with VaadinIcon enums (VaadinIcon.USER and VaadinIcon.AUTOMATION). You can also use the setUserImage(String url) method to set an image from a URL.

MessageInput: This component provides a user-friendly input field with a send button, simplifying the process of capturing user input.

Event Handling: The addSubmitListener on the MessageInput component allows you to define the logic that executes when a user sends a message.

Dynamic Updates: To ensure the MessageList refreshes with new messages, it's good practice to provide it with a new List instance.

This example provides a solid foundation for building more advanced chatbot functionalities, such as integrating with a natural language processing (NLP) service for more intelligent responses.

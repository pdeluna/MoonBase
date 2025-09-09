graph TD
    %% Repository Layer (Bottom)
    PR[profileRepositoryProvider] --> SC[sessionProvider]
    BR[basesRepositoryProvider] --> BP[basesProvider]
    CR[chatRepositoryProvider] --> CMP[chatMessagesProvider]
    CR --> CAP[chatActionsProvider]
    IR[invitesRepositoryProvider] --> IP[invitesProvider]
    
    %% Session Layer
    SC --> BP
    SC --> SBP[selectedBaseProvider]
    SC --> CMP
    SC --> CAP
    SC --> AP[authStateProvider]
    
    %% Base Management Layer
    BP --> MRBP[mostRecentBaseProvider]
    SBP --> ESBP[effectiveSelectedBaseProvider]
    MRBP --> ESBP
    ESBP --> CAP
    
    %% Chat Layer
    CMP --> CMP_FAMILY[chatMessagesProvider.family<br/>per baseId]
    CAP --> CAP_STATE[ChatActionsNotifier]
    
    %% Router Layer
    AP --> RP[routerProvider]
    
    %% UI Dependencies
    ESBP --> CHAT_UI[ChatScreen]
    CMP_FAMILY --> CHAT_UI
    CAP_STATE --> CHAT_UI
    
    %% Profile Management
    PR --> PBUP[profileByUserIdProvider.family<br/>per userId]
    
    %% Base Members
    BR --> BMP[baseMembersProvider.family<br/>per baseId]
    
    %% Invites
    IR --> BIP[baseInvitesProvider.family<br/>per baseId]
    IR --> IVP[inviteValidationProvider.family<br/>per code]
    
    %% Styling
    classDef repository fill:#e1f5fe
    classDef session fill:#f3e5f5
    classDef base fill:#e8f5e8
    classDef chat fill:#fff3e0
    classDef router fill:#fce4ec
    classDef ui fill:#f1f8e9
    
    class PR,BR,CR,IR repository
    class SC,PBUP session
    class BP,SBP,MRBP,ESBP,BMP base
    class CMP,CAP,CMP_FAMILY,CAP_STATE chat
    class AP,RP router
    class CHAT_UI ui
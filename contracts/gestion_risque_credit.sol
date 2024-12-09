// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GestionnaireRisqueContrepartie {
    struct Contrepartie {
        address portefeuille;
        uint256 scoreCredit;
        uint256 limiteExposition;
        uint256 expositionCourante;
        uint256 positionsLongues;
        uint256 positionsCourtes;
        uint256 collateraux;
        bool estActif;
    }

    struct Transaction {
        address de;
        address vers;
        uint256 montant;
        bool isLong;
        uint256 timestamp;
    }

    mapping(address => Contrepartie) public contreparties;
    mapping(address => mapping(address => uint256)) public expositions;
    Transaction[] public transactions; // Tableau pour stocker l'historique des transactions

    event ContrepartieAjoutee(address indexed contrepartie, uint256 limiteExposition);
    event ExpositionMiseAJour(address indexed _de, address indexed _vers, uint256 nouvelleExposition, int256 expositionNette, uint256 ratioCouverture);
    event LimiteDepassee(address indexed contrepartie, uint256 exposition);
    event TransactionEnregistree(address indexed _de, address indexed _vers, uint256 _montant, bool _isLong);


    function ajouterContrepartie(address _portefeuille, uint256 _scoreCredit, uint256 _limiteExposition) public {
        require(_portefeuille != address(0), "Adresse invalide");
        require(_scoreCredit > 0, "Score de credit doit etre positif");
        require(_limiteExposition > 0, "Limite d'exposition invalide");

        contreparties[_portefeuille] = Contrepartie(_portefeuille, _scoreCredit, _limiteExposition, 0, 0, 0, 0, true);
        emit ContrepartieAjoutee(_portefeuille, _limiteExposition);
    }

    function mettreAJourExposition(address _de, address _vers, uint256 _nouvelleExposition, bool isLong) public {
        Contrepartie storage cDe = contreparties[_de];
        Contrepartie storage cVers = contreparties[_vers];

        require(cDe.estActif, "Contrepartie source inactive");
        require(cVers.estActif, "Contrepartie cible inactive");

        expositions[_de][_vers] = _nouvelleExposition;

        if (isLong) {
            cDe.positionsLongues += _nouvelleExposition;
        } else {
            cDe.positionsCourtes += _nouvelleExposition;
        }

        cDe.expositionCourante = cDe.positionsLongues + cDe.positionsCourtes;

        int256 expositionNette = int256(cDe.positionsLongues) - int256(cDe.positionsCourtes);
        uint256 ratioCouverture = cDe.collateraux > 0 && cDe.expositionCourante > 0 ? cDe.collateraux / cDe.expositionCourante : 0;

        if (cDe.expositionCourante > cDe.limiteExposition) {
            emit LimiteDepassee(_de, cDe.expositionCourante);
        }

        // Enregistrement de la transaction dans l'historique
        transactions.push(Transaction(_de, _vers, _nouvelleExposition, isLong, block.timestamp));
        emit TransactionEnregistree(_de, _vers, _nouvelleExposition, isLong);
        emit ExpositionMiseAJour(_de, _vers, _nouvelleExposition, expositionNette, ratioCouverture);
    }

    function calculerRisque(address _portefeuille) public view returns (uint256 risque) {
        Contrepartie memory c = contreparties[_portefeuille];
        require(c.estActif, "Contrepartie inactive ou inexistante");

        if (c.limiteExposition == 0 || c.scoreCredit == 0) return 0;

        unchecked {
            risque = (c.expositionCourante * 100) / c.limiteExposition * c.scoreCredit;
        }
    }

    function ajouterCollateraux(address _portefeuille, uint256 _montant) public {
        Contrepartie storage c = contreparties[_portefeuille];
        require(c.estActif, "Contrepartie inactive ou inexistante");
        c.collateraux += _montant;
    }

    // Fonction pour récupérer l'historique des transactions
    function getTransactionHistory() public view returns (Transaction[] memory) {
        return transactions;
    }

    // Fonction pour récupérer l'historique des transactions pour une contrepartie spécifique
    function getTransactionHistoryForCounterparty(address _counterparty) public view returns (Transaction[] memory) {
        Transaction[] memory history = new Transaction[](transactions.length);
        uint256 count = 0;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (transactions[i].de == _counterparty || transactions[i].vers == _counterparty) {
                history[count] = transactions[i];
                count++;
            }
        }
        // Resize the array to the actual number of transactions
        assembly {
            mstore(history, count)
        }
        return history;
    }
}